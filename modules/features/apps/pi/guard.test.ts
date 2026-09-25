// Run with: node --test modules/features/apps/pi/guard.test.ts
// (also built by `nix flake check` as checks.pi-guard)
import assert from "node:assert/strict";
import { test } from "node:test";
import guard from "./guard.ts";

type Result = { block: true; reason: string } | undefined;
type Handler = (event: unknown, ctx: unknown) => Promise<Result>;

let handler: Handler | undefined;
guard({ on: (_name: string, h: Handler) => (handler = h) } as never);

const CWD = "/home/u/proj";

// Runs one tool call through the guard. `answer` is what the user picks if a
// confirmation is shown; `ui: false` simulates no UI (print / some RPC modes).
async function run(toolName: string, input: Record<string, unknown>, opts: { ui?: boolean; answer?: string } = {}) {
	const asked: string[] = [];
	const ctx = {
		cwd: CWD,
		hasUI: opts.ui ?? true,
		ui: {
			notify: () => {},
			select: async (title: string) => {
				asked.push(title);
				return opts.answer ?? "No";
			},
		},
	};
	const result = await handler!({ toolName, input }, ctx);
	return { result, asked };
}
const bash = (command: string, opts?: { ui?: boolean; answer?: string }) => run("bash", { command }, opts);

const blocked = async (r: ReturnType<typeof run>) => assert.equal((await r).result?.block, true);
const allowed = async (r: ReturnType<typeof run>) => {
	const { result, asked } = await r;
	assert.equal(result, undefined);
	assert.deepEqual(asked, []);
};

test("ansible-playbook needs --check", async () => {
	await blocked(bash("ansible-playbook site.yml"));
	await blocked(bash("cd infra && ansible-playbook -i inv site.yml --diff"));
	await blocked(bash("devenv shell -- ansible-playbook site.yml"));
	await allowed(bash("ansible-playbook site.yml --check"));
	await allowed(bash("ansible-playbook -C site.yml"));
	await allowed(bash("ansible-playbook site.yml --syntax-check"));
	await allowed(bash("ansible-lint site.yml"));
	await allowed(bash('git commit -m "ansible-playbook docs"'));
});

test("switching configurations asks; remote targets are blocked", async () => {
	for (const cmd of [
		"nixos-rebuild switch --flake .#thomas-desktop",
		"sudo nixos-rebuild boot --flake .",
		"nixos-rebuild test",
		"home-manager switch",
		"nh os switch",
	]) {
		const yes = await bash(cmd, { answer: "Yes" });
		assert.equal(yes.result, undefined, cmd);
		assert.equal(yes.asked.length, 1, cmd);
		assert.equal((await bash(cmd, { answer: "No" })).result?.block, true, cmd);
		assert.equal((await bash(cmd, { ui: false })).result?.block, true, cmd);
	}
	await blocked(bash("nixos-rebuild switch --flake .#h --target-host root@h"));
	await blocked(bash("nixos-rebuild build --build-host h --flake ."));
	await allowed(bash("nixos-rebuild build --flake .#thomas-desktop"));
	await allowed(bash("nixos-rebuild dry-activate --flake ."));
	await allowed(bash("home-manager build"));
});

test("flake.lock and go.sum are not hand-edited", async () => {
	await blocked(run("write", { path: "flake.lock", content: "{}" }));
	await blocked(run("edit", { path: "/home/u/proj/services/x/go.sum", edits: [] }));
	await blocked(bash("sed -i 's/a/b/' flake.lock"));
	await blocked(bash("echo x > go.sum"));
	await blocked(bash("cat new > flake.lock"));
	await blocked(bash("rm go.sum"));
	await allowed(run("read", { path: "flake.lock" }));
	await allowed(bash("grep nixpkgs flake.lock"));
	await allowed(bash("git diff flake.lock"));
	await allowed(bash("nix flake update nixpkgs"));
	await allowed(bash("go mod tidy"));
});

test("secrets cannot be read or written", async () => {
	await blocked(run("read", { path: "secrets/mirror-ssh.age" }));
	await blocked(run("write", { path: "/home/u/proj/secrets/x", content: "" }));
	await blocked(run("read", { path: "/run/agenix/mirror-ssh" }));
	await blocked(run("read", { path: "~/.config/age/keys.txt" }));
	await blocked(run("read", { path: "infra/platform/ansible/group_vars/all/vault.yml" }));
	await blocked(run("read", { path: ".sops.yaml" }));
	await blocked(run("read", { path: "/home/u/.pi/agent/auth.json" }));
	await blocked(bash("cat secrets/mirror-ssh.age"));
	await blocked(bash("cp /run/agenix/x /tmp/x"));
	await blocked(bash("ansible-vault view group_vars/all/vault.yml"));
	await blocked(bash("sops -d secrets.yaml"));
	await blocked(bash("cat ~/.config/age/keys.txt"));
	await allowed(run("read", { path: "secrets.nix" }));
	await allowed(run("read", { path: "README.md" }));
	await allowed(bash('git commit -m "handle secrets and vault better"'));
	await allowed(bash("grep -rn secrets README.md"));
});

test("rm -rf outside the project asks", async () => {
	for (const cmd of ["rm -rf /", "rm -rf ~/projects", "rm -rf ../other", "rm -fr /tmp/x", "rm -r $DIR", "rm -rf *", "rm -rf ."]) {
		assert.equal((await bash(cmd, { answer: "No" })).result?.block, true, cmd);
		assert.equal((await bash(cmd, { ui: false })).result?.block, true, cmd);
		assert.equal((await bash(cmd, { answer: "Yes" })).result, undefined, cmd);
	}
	await allowed(bash("rm -rf node_modules"));
	await allowed(bash("rm -rf ./build /home/u/proj/dist"));
	await allowed(bash("rm file.txt"));
	await allowed(bash("rm -f /tmp/x"));
});

test("ordinary work is untouched", async () => {
	await allowed(bash("ls -la && git status"));
	await allowed(bash("go test ./... | tail"));
	await allowed(run("read", { path: "src/main.go" }));
	await allowed(run("edit", { path: "src/main.go", edits: [] }));
	await allowed(run("grep", { pattern: "x" }));
});
