# Pi coding agent setup

Everything for running [Pi](https://pi.dev) the same way on every machine, declared in Nix:
the agent, its extensions, language servers, MCP servers, a permission guard, and Zed
integration. This directory is self-contained so it can be shared inside a company; the
rest of this repo only uses it (glue in `modules/features/apps/pi.nix`).

```
home-module.nix   Home Manager module: options under programs.pi-agent.*
orchestration.nix default agents and the orchestrator's instructions (plain data)
overlay.nix       the packages it needs, as an overlay (import ./overlay.nix { })
packages/         pi-agent (Pi + tools on PATH), extensions, kotlin-lsp, minecraft-mcp-server
guard/            the permission guard extension and its tests
```

## What you get

| Piece | What it does |
|---|---|
| `pi-agent` | Pi 0.87.x with gopls, nixd, yaml/ansible/bash language servers, shellcheck, shfmt, jq, gh, node and uv on its PATH. Appended, so a project's own devenv toolchain wins. |
| pi-mcp-adapter | MCP servers, connected on first use. Defaults: gopls, mcp-nixos, GitHub (via `gh auth token`). |
| pi-lsp | Diagnostics after every edit: Go, Nix, YAML, Ansible, Bash, Kotlin (x86_64-linux only). |
| pi-subagents | Sub-agents, plus the orchestration set-up below. |
| pi-auto-model | Routes each task to a suitable model among those you have credentials for. |
| guard | Blocks or asks before dangerous commands and secret access; see the header of `guard/guard.ts`. |
| Zed | `programs.pi-agent.zed.enable` adds Pi as an agent server (through pi-acp). |

## Using it from another flake

```nix
{
  inputs.pi-setup.url = "github:<org>/<repo>";   # wherever this directory ends up
  inputs.nixpkgs.follows = "pi-setup/nixpkgs";   # or your own, see "Compatibility"
  inputs.home-manager.url = "github:nix-community/home-manager";

  outputs = { pi-setup, nixpkgs, home-manager, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;              # kotlin-lsp
        overlays = [ pi-setup.overlays.pi ];
      };
      modules = [
        pi-setup.homeModules.pi-agent
        { programs.pi-agent.enable = true; }
      ];
    };
  };
}
```

On NixOS with Home Manager as a module, add `overlays.pi` to `nixpkgs.overlays` and the module to
`home-manager.users.<name>.imports`. (`overlays.pi` is what this repo's own hosts use, via
`overlays.default`.)

## Multi-agent work

The main session is an orchestrator. It is told (`APPEND_SYSTEM.md`, from
`orchestration.instructions`) to do small changes itself and to delegate broad or parallel
work with pi-subagents' `Agent` tool: exploration to `explorer`s in parallel, changes to
`implementer`s, then a `reviewer`, briefing each fully because subagents do not see the
conversation, and verifying what comes back. The agents (`orchestration.nix`, installed to
`~/.pi/agent/agents/`):

| Agent | Tools | Role |
|---|---|---|
| `explorer` | read, grep, find, ls, bash | read-only investigation; short report with `path:line` evidence |
| `implementer` | all | one specified change; verifies and reports files, checks run, doubts |
| `go-`, `kotlin-`, `nix-`, `ansible-implementer` | all | the same, with each language's verification steps (Nix: build, never switch; Ansible: lint and `--check`, never apply) |
| `reviewer` | read, grep, find, ls, bash | read-only review; findings by severity with evidence |

pi-subagents' own `Explore`, `Plan` and `general-purpose` stay available. The `Agent` tool's
description lists every agent, so the orchestrator picks by the descriptions.

Tune or add agents through `programs.pi-agent.agents`, one field at a time:

```nix
programs.pi-agent.agents = {
  explorer.model = "haiku";                       # a cheaper model for exploration
  go-implementer.frontmatter.isolation = "worktree";
  security-auditor = {
    description = "Reviews changes for security problems";
    tools = "read, grep, find";
    prompt = "You are a security auditor. ...";
  };
  kotlin-implementer.enable = false;
};
programs.pi-agent.orchestration.enable = false;   # no orchestration text or default agents
```

Subagents run with the guard: agents do not set `extensions:` or `isolated:`, because an agent
that skips extensions also skips the guard (keep that in agents you add). `subagents.settings`
is pi-subagents' `subagents.json` (concurrency, turn limits; cost and model are shown by default).

## Layers: shared defaults, team settings, personal

The module's defaults are meant to be right for anyone. Put company-wide choices in a module of
your own that sets `programs.pi-agent.*` and is imported alongside it, then let each person add
theirs:

```nix
# company.nix -- the shared layer
{ lib, ... }: {
  programs.pi-agent = {
    env = { CLOUDFLARE_ACCOUNT_ID = "..."; CLOUDFLARE_GATEWAY_ID = "..."; };   # not secret
    settingsDefaults.defaultProvider = "cloudflare-ai-gateway";
    context = ''
      Run the linters before you say you are done. Never edit generated code.
    '';
    skills.deploy = ./skills/deploy;                # a directory with a SKILL.md
    guard.blockCommands = [
      { pattern = "\\bterraform apply\\b"; reason = "apply through CI"; }
    ];
    guard.lockedFiles = [ "flake.lock" "go.sum" "package-lock.json" ];
    lsp.servers.terraform = { bin = "terraform-ls"; args = [ "serve" ]; include = [ "**/*.tf" ]; rootMarkers = [ ".terraform" ]; };
  };
}

# a person's own module
{ programs.pi-agent.mcp.servers.github.disabled = true; }
```

Servers and language servers are merged per field, so overriding one is
`lsp.servers.gopls.enabled = false;` or `mcp.servers.github.args = [ ... ];`, without restating
the rest. A field holding a whole attrset (`settings`) is replaced as a unit.

### Secrets

Nothing secret belongs in these options: everything ends up in the Nix store, which is
world-readable. Each person supplies their own key, for the Cloudflare AI Gateway
`CLOUDFLARE_API_KEY` (through `/login` in Pi, or their environment). Account and gateway IDs
are not secret and go in `env`, which is applied on the Pi wrapper so it reaches Pi from a
terminal and from Zed alike. `models.json` (custom endpoints) can take `apiKey = "!command"`
so the key is read at run time instead.

### Company skills, prompts and extensions

`skills` and `context` cover the simple cases. Anything bigger (extensions, prompt
templates, themes, several skills together) is a Pi package: build it as a derivation laid out
as `lib/node_modules/<name>/` (see `packages/extensions.nix` for examples) and list it in
`programs.pi-agent.packages`.

## Compatibility

* Written for Linux; the `kotlin-lsp` package is x86_64-linux only, and the Kotlin server and
  tool are left out elsewhere. macOS and aarch64 have **not** been tried.
* Pi and the extensions are pinned to what was tested together. `nixpkgs` follows this flake by
  default; another nixpkgs works as long as it has the tools named in `packages/pi-agent.nix`.
* `overlays.pi` takes an optional `minecraftMcpServerSrc` (see `overlay.nix`) for the Minecraft
  bot package.

## Updating

All versions are pinned in this directory; each file says how to bump it:

* Pi itself: `overlay.nix` (version and three hashes).
* Extensions and pi-acp: `packages/extensions.nix` (version, source hash, `npmDepsHash`). The
  files in `packages/lockfiles/` are upstream's lockfile pruned of dev/peer dependencies (and,
  for pi-lsp, generated from scratch); regenerate one with
  `npm install --package-lock-only --ignore-scripts` in a copy of the package with those
  dependency sections removed.
* kotlin-lsp: `packages/kotlin-lsp.nix`.
* The guard's rules: `guard/guard.ts`; run its tests with `node --test guard/guard.test.ts`
  (this repo also runs them in `nix flake check`).

## Moving it into its own repository

The directory has no references outside itself. To share it: copy `pi/` to a new repo with a
small `flake.nix` that exports `overlays.pi = import ./overlay.nix { };`,
`homeModules.pi-agent = ./home-module.nix;` and the packages, then replace
`modules/features/apps/pi.nix` here with an input on it.

## Known limits

* The guard reads command text; it is a guard rail, not a sandbox (see its header).
* pi-lsp reads `PI_AGENT_DIR` (default `~/.pi/agent`), not `PI_CODING_AGENT_DIR`, so both need
  setting if the agent directory is moved.
* Nothing here tests how a *background* subagent answers a guard confirmation in the terminal UI
  (without a UI, confirmations are refused; blocks apply everywhere).
* pi-lsp's `lsp_diagnostics` tool reported "no diagnostics" right after edits that had errors
  (diagnostics attached to the edit result itself were right).
* Kotlin diagnostics after the first edit can be empty until the initial Gradle import
  finishes (about a minute).
* pi-auto-model refreshes a price catalog from GitHub daily; turn that off with
  `autoModel.settings.pricing.litellm.enabled = false`.
