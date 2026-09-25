/**
 * Guard extension: Pi has no permission system of its own, so this blocks (or
 * asks about) a handful of things before a tool call runs. Forked from the
 * permission-gate.ts and protected-paths.ts examples in earendil-works/pi
 * (packages/coding-agent/examples/extensions/).
 *
 * BLOCK (never runs; there is no prompt):
 *   - ansible-playbook without --check / -C (or a --syntax-check / --list-*
 *     run, which executes nothing)
 *   - nixos-rebuild aimed at a remote host (--target-host / --build-host)
 *   - writing to flake.lock or go.sum by hand (use `nix flake lock|update`,
 *     `go mod tidy`, which are not touched)
 *   - reading or writing vault / sops / agenix secrets and Pi's own auth.json
 * CONFIRM (asks; blocked when there is no UI to ask):
 *   - nixos-rebuild switch|boot|test, home-manager switch, nh ... switch
 *   - rm -rf whose target is not inside the project directory
 *
 * This is a guard rail, not a sandbox. It reads the command text, so a script
 * that does the dangerous thing internally, an indirect invocation
 * (`sh -c "$cmd"`, a variable) or a tool from another extension / MCP server
 * gets past it. It stops the model blundering, not a determined workaround.
 *
 * Configuration: `guard.json` in the agent directory (~/.pi/agent), all keys
 * optional and additive to the built-in rules above except lockedFiles, which
 * replaces the default list (flake.lock, go.sum):
 *   { "lockedFiles": ["flake.lock", "Cargo.lock"],
 *     "secretPathPatterns": ["\\.env$"],                    // JS regexes, tried on absolute paths
 *     "blockCommands":   [{ "pattern": "\\bterraform apply\\b", "reason": "plan first" }],
 *     "confirmCommands": [{ "pattern": "\\bkubectl delete\\b", "reason": "deletes cluster objects" }] }
 * (Nix: programs.pi-agent.guard.*.) An invalid guard.json makes the guard block
 * every tool call rather than run unguarded.
 *
 * Note that Pi's `!cmd` (user-typed shell) is not a model tool call and is not
 * checked.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Verdict = { kind: "allow" } | { kind: "block"; reason: string } | { kind: "confirm"; reason: string };
const allow: Verdict = { kind: "allow" };

// ---- paths ---------------------------------------------------------------

const BUILTIN_SECRET_PATTERNS: RegExp[] = [
	/(^|\/)secrets(\/|$)/i,
	/\.age$/i,
	/^\/run\/agenix(\/|$)/,
	/^\/var\/lib\/agenix(\/|$)/,
	/\/\.config\/age(\/|$)/,
	/\/[^/]*vault[^/]*(\/|$)/i,
	/\/[^/]*sops[^/]*(\/|$)/i,
	/\/\.pi\/agent\/auth\.json$/,
];
const DEFAULT_LOCKED_FILES = ["flake.lock", "go.sum"];

export interface CommandRule {
	pattern: string;
	reason: string;
}
export interface GuardConfig {
	lockedFiles?: string[];
	secretPathPatterns?: string[];
	blockCommands?: CommandRule[];
	confirmCommands?: CommandRule[];
}
interface Rules {
	locked: string[];
	secret: RegExp[];
	block: { re: RegExp; reason: string }[];
	confirm: { re: RegExp; reason: string }[];
}

function compileRules(config: GuardConfig): Rules {
	const compile = (r: CommandRule) => ({ re: new RegExp(r.pattern), reason: r.reason });
	return {
		locked: config.lockedFiles ?? DEFAULT_LOCKED_FILES,
		secret: [...BUILTIN_SECRET_PATTERNS, ...(config.secretPathPatterns ?? []).map((p) => new RegExp(p, "i"))],
		block: (config.blockCommands ?? []).map(compile),
		confirm: (config.confirmCommands ?? []).map(compile),
	};
}

function absolutePath(p: string, cwd: string): string {
	let expanded = p;
	if (expanded === "~") expanded = homedir();
	else if (expanded.startsWith("~/")) expanded = homedir() + expanded.slice(1);
	else if (expanded.startsWith("$HOME/")) expanded = homedir() + expanded.slice(5);
	return isAbsolute(expanded) ? resolve(expanded) : resolve(cwd, expanded);
}

function isSecretPath(p: string, cwd: string, rules: Rules): boolean {
	const abs = absolutePath(p, cwd);
	return rules.secret.some((re) => re.test(abs));
}

function isLockedFile(p: string, cwd: string, rules: Rules): boolean {
	const base = absolutePath(p, cwd).split(sep).pop() ?? "";
	return rules.locked.includes(base);
}

function inside(p: string, cwd: string): boolean {
	return absolutePath(p, cwd).startsWith(resolve(cwd) + sep);
}

// ---- bash ------------------------------------------------------------------

// Rough split into simple commands. Quoted separators split wrongly, which
// only ever makes the check stricter or misses an exotic case; see the note
// on being a guard rail.
function segments(command: string): string[] {
	return command
		.split(/&&|\|\||[;|\n]/)
		.map((s) => s.trim())
		.filter(Boolean);
}

// Words of one simple command with quotes stripped, for path checks.
function words(segment: string): string[] {
	return segment.split(/[\s'"<>()`]+/).filter(Boolean);
}

// Commands that print, search or record text rather than run their arguments:
// `git commit -m "ansible-playbook docs"` or `grep -r nixos-rebuild .` name a
// dangerous command without running one, so the command-name rules skip them.
const INERT = new Set(["echo", "printf", "git", "grep", "rg", "egrep", "fgrep", "cat", "bat", "less", "man", "which", "type", "head", "tail", "wc", "ls", "eza"]);
const isInert = (ws: string[]) => INERT.has((ws.find((w) => !/^\w+=/.test(w)) ?? "").split("/").pop() ?? "");

// A bare word like `secrets` in a commit message or grep pattern is not a
// path; only words that read as one are checked against the secret patterns.
const looksLikePath = (w: string) =>
	w.includes("/") || w.startsWith("~") || /\.age$|auth\.json$/.test(w) || (/(vault|sops)/i.test(w) && /\.\w+$/.test(w));

const flagsOf = (ws: string[]) => ws.filter((w) => w.startsWith("-"));

function checkBash(command: string, cwd: string, rules: Rules): Verdict {
	let confirm: Verdict = allow;

	for (const seg of segments(command)) {
		const ws = words(seg);
		const inert = isInert(ws);

		// secrets: any word that looks like a path to one (reading or writing)
		for (const w of ws) {
			if (looksLikePath(w) && isSecretPath(w, cwd, rules)) {
				return { kind: "block", reason: `touches a secret file (${w})` };
			}
		}
		if (!inert && ws.some((w) => /(^|\/)(ansible-vault|sops|agenix)$/.test(w))) {
			return { kind: "block", reason: "secret tooling (ansible-vault / sops / agenix)" };
		}

		// ansible-playbook without --check
		if (!inert && ws.some((w) => /(^|\/)ansible-playbook$/.test(w))) {
			const safe = /(^|\s)(--check|-C|--syntax-check|--list-hosts|--list-tasks|--list-tags)(\s|=|$)/.test(seg);
			if (!safe) return { kind: "block", reason: "ansible-playbook without --check (dry run first)" };
		}

		// hand edits to flake.lock / go.sum
		if (ws.some((w) => rules.locked.includes(w.split("/").pop() ?? ""))) {
			const writes =
				/>|\btee\b|\bsed\b.*\s-[a-zA-Z]*i|\bperl\b.*\s-[a-zA-Z]*i|\b(mv|cp|rm|truncate|install|ln|dd)\b|\b(python3?|node|ruby)\b/.test(
					seg,
				);
			if (writes) return { kind: "block", reason: "flake.lock / go.sum are not edited by hand" };
		}

		// site-specific rules from guard.json
		if (!inert) {
			const blocked = rules.block.find((r) => r.re.test(seg));
			if (blocked) return { kind: "block", reason: blocked.reason };
			const asked = rules.confirm.find((r) => r.re.test(seg));
			if (asked) confirm = { kind: "confirm", reason: asked.reason };
		}

		// nixos-rebuild / home-manager / nh
		const rebuild = /\bnixos-rebuild(-ng)?\b/.test(seg) || /\bnh\s+(os|home)\b/.test(seg);
		const hm = /\bhome-manager\b/.test(seg);
		if (!inert && (rebuild || hm)) {
			if (/--(target|build)-host\b/.test(seg)) {
				return { kind: "block", reason: "remote nixos-rebuild (--target-host / --build-host)" };
			}
			const activates = rebuild
				? /(^|\s)(switch|boot|test)(\s|$)/.test(seg)
				: /(^|\s)switch(\s|$)/.test(seg);
			if (activates) confirm = { kind: "confirm", reason: "activates a new system / home configuration" };
		}
		if (!inert && /\bswitch-to-configuration\b/.test(seg)) {
			confirm = { kind: "confirm", reason: "activates a new system configuration" };
		}

		// rm -rf outside the project
		if (!inert && ws.includes("rm")) {
			const flags = flagsOf(ws);
			const recursive = flags.some((f) => /^--recursive$/.test(f) || /^-[a-zA-Z]*[rR]/.test(f));
			if (recursive) {
				const targets = ws.slice(ws.indexOf("rm") + 1).filter((w) => !w.startsWith("-"));
				const unknown = (t: string) => /[$*?[]/.test(t);
				const outside = targets.some((t) => unknown(t) || !inside(t, cwd));
				if (outside) confirm = { kind: "confirm", reason: `rm -r outside the project directory: ${targets.join(" ")}` };
			}
		}
	}
	return confirm;
}

// ---- other tools -----------------------------------------------------------

function pathsOf(input: Record<string, unknown>): string[] {
	const out: string[] = [];
	for (const key of ["path", "file_path", "filePath", "file"]) {
		const v = input[key];
		if (typeof v === "string") out.push(v);
	}
	if (Array.isArray(input.paths)) out.push(...input.paths.filter((v): v is string => typeof v === "string"));
	return out;
}

function checkTool(toolName: string, input: Record<string, unknown>, cwd: string, rules: Rules): Verdict {
	if (toolName === "bash") {
		return typeof input.command === "string" ? checkBash(input.command, cwd, rules) : allow;
	}
	for (const p of pathsOf(input)) {
		if (isSecretPath(p, cwd, rules)) return { kind: "block", reason: `secret file (${p})` };
		if ((toolName === "write" || toolName === "edit") && isLockedFile(p, cwd, rules)) {
			return { kind: "block", reason: `${p} is not edited by hand` };
		}
	}
	return allow;
}

export function createGuard(config: GuardConfig) {
	const rules = compileRules(config);
	return (pi: ExtensionAPI) => {
		pi.on("tool_call", async (event, ctx) => {
			const cwd = (ctx as { cwd?: string }).cwd ?? process.cwd();
			const verdict = checkTool(event.toolName, event.input as Record<string, unknown>, cwd, rules);
			if (verdict.kind === "allow") return undefined;

			if (verdict.kind === "block") {
				if (ctx.hasUI) ctx.ui.notify(`Guard blocked ${event.toolName}: ${verdict.reason}`, "warning");
				return { block: true, reason: `Blocked by guard: ${verdict.reason}` };
			}

			if (!ctx.hasUI) {
				return { block: true, reason: `Blocked by guard (${verdict.reason}; no UI to confirm)` };
			}
			const detail = event.toolName === "bash" ? String((event.input as { command?: string }).command) : event.toolName;
			const choice = await ctx.ui.select(`⚠️ ${verdict.reason}\n\n  ${detail}\n\nAllow?`, ["Yes", "No"]);
			if (choice !== "Yes") return { block: true, reason: "Blocked by user" };
			return undefined;
		});
	};
}

function loadConfig(): GuardConfig {
	const dir = process.env.PI_CODING_AGENT_DIR ?? `${homedir()}/.pi/agent`;
	const file = `${dir}/guard.json`;
	return existsSync(file) ? (JSON.parse(readFileSync(file, "utf8")) as GuardConfig) : {};
}

export default function (pi: ExtensionAPI) {
	let guard: (pi: ExtensionAPI) => void;
	try {
		guard = createGuard(loadConfig());
	} catch (error) {
		// Fail closed: a broken config must not silently turn the guard off.
		const reason = `guard.json is invalid (${(error as Error).message}); blocking all tool calls until it is fixed`;
		guard = (p) => p.on("tool_call", async () => ({ block: true, reason }));
	}
	guard(pi);
}
