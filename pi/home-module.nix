# Home Manager module for the Pi coding agent (pi.dev): the agent, its
# extensions, LSP + MCP servers, a permission guard and (optionally) Zed
# integration, all declared through options and nothing installed with
# `pi install` or npm.
#
# Self-contained: it needs nothing from the repo it lives in except the
# overlay next to it (./overlay.nix) applied to `pkgs`, so a team can consume
# it from a shared flake (see ./README.md). Personal or company specifics
# belong in the configuration that *uses* it, not here.
#
# Files written (all under ~/.pi/agent unless noted; read-only symlinks into
# the Nix store, except settings.json which Pi also writes -- see
# `settingsDefaults`):
#   lsp.json, guard.json, auto-model.json, models.json, AGENTS.md, skills/*,
#   extensions/guard.ts, and ~/.config/mcp/mcp.json.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.pi-agent;
  ext = pkgs.piExtensions;
  jsonFormat = pkgs.formats.json { };
  inherit (lib) mkOption mkEnableOption types;
  orchestration = import ./orchestration.nix;

  # Per-server settings are free-form JSON (whatever pi-lsp / pi-mcp-adapter
  # accept), keyed by id in the option and listed in the generated file.
  serverType = types.attrsOf (types.attrsOf jsonFormat.type);
  ruleType = types.submodule {
    options = {
      pattern = mkOption {
        type = types.str;
        description = "JavaScript regular expression, tried on each simple command.";
      };
      reason = mkOption {
        type = types.str;
        description = "Shown to the model (and to you, when asked to confirm).";
      };
    };
  };

  # An agent for pi-subagents is a Markdown file: YAML frontmatter, then the
  # system prompt. JSON scalars are valid YAML, so values are written as JSON.
  agentFile =
    a:
    let
      known = lib.filterAttrs (_: v: v != null) {
        inherit (a)
          description
          tools
          model
          thinking
          ;
        max_turns = a.maxTurns;
        inherit (a) color;
      };
      frontmatter = known // a.frontmatter;
    in
    ''
      ---
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}: ${builtins.toJSON v}") frontmatter)}
      ---

      ${a.prompt}'';
  agentType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this agent is installed (turn a default one off with `enable = false`).";
      };
      description = mkOption {
        type = types.str;
        description = "What the agent is for. The orchestrator reads this to decide when to spawn it.";
      };
      prompt = mkOption {
        type = types.lines;
        description = "The agent's system prompt.";
      };
      tools = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "read, grep, find, ls";
        description = "Comma-separated built-in tools the agent may use; null means all.";
      };
      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "haiku";
        description = "`provider/model` or a fuzzy name; null inherits the spawning agent's model.";
      };
      thinking = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Thinking level (off, minimal, low, medium, high, xhigh, max); null inherits.";
      };
      maxTurns = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Agentic turns before the agent is asked to wrap up; null is unlimited.";
      };
      color = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Badge colour in the UI.";
      };
      frontmatter = mkOption {
        type = types.attrsOf jsonFormat.type;
        default = { };
        example = {
          isolation = "worktree";
        };
        description = ''
          Any other pi-subagents frontmatter key (`isolation`, `memory`,
          `allowed_subagents`, ...). Do not set `extensions` or `isolated`
          unless you also want the agent to run without the guard.
        '';
      };
    };
  };

  # A Pi `packages` entry: a store path, or a derivation laid out like the
  # extensions in ./packages/extensions.nix.
  packagePath = p: if lib.isString p then p else ext.extensionPath p;
  builtinPackages =
    lib.optional cfg.mcp.enable ext.pi-mcp-adapter
    ++ lib.optional cfg.subagents.enable ext.pi-subagents
    ++ lib.optional cfg.lsp.enable ext.pi-lsp
    ++ lib.optional cfg.autoModel.enable ext.pi-auto-model;
  packagePaths = map packagePath (builtinPackages ++ cfg.packages);

  kotlinAvailable = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.kotlin-lsp;

  # gh's token, fetched when the server starts, so nothing secret is stored in
  # the config; needs a prior `gh auth login`.
  github-mcp = pkgs.writeShellApplication {
    name = "github-mcp";
    runtimeInputs = [
      pkgs.gh
      pkgs.github-mcp-server
    ];
    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server stdio
    '';
  };

  # Globs are matched against the path relative to each server's root (the
  # nearest directory with one of its rootMarkers). Bare `bin` names resolve
  # through PATH, so a project's devenv toolchain wins over the copies in
  # pi-agent.
  server =
    bin: args: extra:
    {
      inherit bin args;
      enabled = true;
      cwd = "{root}";
    }
    // extra;
  ansibleGlobs = lib.concatMap (dir: [
    "**/${dir}/**/*.yaml"
    "**/${dir}/**/*.yml"
  ]) cfg.lsp.ansibleDirs;

  defaultLspServers = {
    gopls = server "gopls" [ ] {
      include = [ "**/*.go" ];
      rootMarkers = [
        "go.work"
        "go.mod"
      ];
      languageIdByExtension.".go" = "go";
      startupTimeoutMs = 60000;
      diagnosticsWaitMs = 3000;
    };
    nixd = server "nixd" [ ] {
      include = [ "**/*.nix" ];
      rootMarkers = [
        "flake.nix"
        ".git"
      ];
      languageIdByExtension.".nix" = "nix";
      diagnosticsWaitMs = 3000;
    };
    # YAML that isn't Ansible; Ansible files go to the server below so they
    # don't get both (and the wrong schemas).
    yaml = server "yaml-language-server" [ "--stdio" ] {
      include = [
        "**/*.yaml"
        "**/*.yml"
      ];
      exclude = ansibleGlobs;
      rootMarkers = [ ".git" ];
      languageIdByExtension = {
        ".yaml" = "yaml";
        ".yml" = "yaml";
      };
      diagnosticsWaitMs = 2000;
    };
    # Ansible files (see ansibleDirs) under a directory with an ansible.cfg.
    # Its linting shells out to ansible-lint.
    ansible = server "ansible-language-server" [ "--stdio" ] {
      include = ansibleGlobs;
      rootMarkers = [
        "ansible.cfg"
        ".ansible-lint"
      ];
      languageIdByExtension = {
        ".yaml" = "ansible";
        ".yml" = "ansible";
      };
      settings.ansible.validation = {
        enabled = true;
        lint = {
          enabled = true;
          path = "ansible-lint";
        };
      };
      startupTimeoutMs = 60000;
      diagnosticsWaitMs = 5000;
    };
    # Runs shellcheck for diagnostics.
    bash = server "bash-language-server" [ "start" ] {
      include = [
        "**/*.sh"
        "**/*.bash"
      ];
      rootMarkers = [ ".git" ];
      languageIdByExtension = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
      };
      diagnosticsWaitMs = 2000;
    };
  }
  # Alpha, and a JVM: imports the Gradle project on first use (over a minute
  # cold), so it gets far longer than the others. Needs the project's
  # Gradle/JDK, i.e. run Pi inside the project's devenv shell.
  // lib.optionalAttrs kotlinAvailable {
    kotlin-lsp = server "kotlin-lsp" [ "--stdio" ] {
      include = [
        "**/*.kt"
        "**/*.kts"
      ];
      rootMarkers = [
        "settings.gradle.kts"
        "settings.gradle"
        "build.gradle.kts"
        "build.gradle"
        "pom.xml"
      ];
      languageIdByExtension = {
        ".kt" = "kotlin";
        ".kts" = "kotlin";
      };
      startupTimeoutMs = 180000;
      diagnosticsWaitMs = 8000;
    };
  };

  # pi-mcp-adapter connects lazily, on the first call to a server's tools.
  defaultMcpServers = {
    # Needs a Go toolchain (from the project's devenv) at call time.
    gopls = {
      command = "gopls";
      args = [ "mcp" ];
    };
    nixos.command = lib.getExe pkgs.mcp-nixos;
    github.command = lib.getExe github-mcp;
  };

  # Every default is `mkDefault` per field, so a server can be turned off
  # (`servers.gopls.enabled = false;` / `.disabled = true;`), tweaked one
  # field at a time, or added, without restating the rest. A field holding an
  # attrset (`settings`) is replaced as a whole.
  asDefaults = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault));

  # Pi rewrites settings.json itself, so it can't be a store symlink. This
  # merges into whatever is there: `packages` is set to this generation's
  # Nix-provided entries (dropping stale /nix/store ones, keeping any added by
  # hand) and `settingsDefaults` fills in keys that aren't set yet. Compared
  # parsed rather than textually, and a file that isn't valid JSON is left
  # alone.
  settingsMerge = ''
    if [[ ! -v DRY_RUN ]]; then
      settings="${config.home.homeDirectory}/.pi/agent/settings.json"
      mkdir -p "$(dirname "$settings")"
      [ -e "$settings" ] || echo '{}' > "$settings"
      if merged="$(${lib.getExe pkgs.jq} \
          --argjson ours '${builtins.toJSON packagePaths}' \
          --argjson seed '${builtins.toJSON cfg.settingsDefaults}' '
          ($seed * .)
          | .packages = (
              ((.packages // [])
                | map(select((if type == "object" then .source else . end)
                             | startswith("/nix/store/") | not)))
              + $ours)' "$settings")"; then
        if [ "$(${lib.getExe pkgs.jq} -cS . <<< "$merged")" != "$(${lib.getExe pkgs.jq} -cS . "$settings")" ]; then
          cp "$settings" "$settings.hm-backup"
          printf '%s\n' "$merged" > "$settings"
        fi
      else
        echo "pi: $settings is not valid JSON; not updating it" >&2
      fi
    fi
  '';

  toFile = name: value: jsonFormat.generate name value;
  writeIfSet =
    path: value: lib.optionalAttrs (value != { }) { ${path}.source = toFile (baseNameOf path) value; };
in
{
  options.programs.pi-agent = {
    enable = mkEnableOption "the Pi coding agent, its extensions and configuration";

    package = mkOption {
      type = types.package;
      default = pkgs.pi-agent.override {
        extraPackages = cfg.tools;
        inherit (cfg) env;
      };
      defaultText = lib.literalExpression "pkgs.pi-agent.override { extraPackages = cfg.tools; inherit (cfg) env; }";
      description = ''
        Pi as installed: the agent with language servers and linters on its
        PATH (appended, so a project's own toolchain wins).
      '';
    };

    tools = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra programs for Pi's PATH, on top of the built-in set.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        CLOUDFLARE_ACCOUNT_ID = "0123456789abcdef";
        CLOUDFLARE_GATEWAY_ID = "engineering";
      };
      description = ''
        Default environment for Pi, for settings that are not secret. Set on
        the wrapper, so it applies however Pi is started (terminal, Zed) and a
        value already in the environment still wins. It ends up in the Nix
        store and is world-readable: keys and tokens do not belong here
        (`CLOUDFLARE_API_KEY` is each user's own, via `/login` or the
        environment).
      '';
    };

    packages = mkOption {
      type = types.listOf (types.either types.str types.package);
      default = [ ];
      description = ''
        Additional Pi packages (extensions, skills, prompts, themes) to load:
        store paths, or derivations laid out as
        `lib/node_modules/<name>` (see `piExtensions` in ./packages/extensions.nix).
      '';
    };

    mcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "pi-mcp-adapter, and ~/.config/mcp/mcp.json for it.";
      };
      servers = mkOption {
        type = serverType;
        default = { };
        example = lib.literalExpression ''{ tracker = { url = "https://mcp.example.com/mcp"; }; }'';
        description = ''
          MCP servers by name, in pi-mcp-adapter's format (`command`/`args`/`env`,
          or `url`; `disabled = true` switches one off). Defaults: gopls,
          mcp-nixos and GitHub (using `gh auth token`).
        '';
      };
    };

    subagents = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "The pi-subagents extension.";
      };
      settings = mkOption {
        inherit (jsonFormat) type;
        default = { };
        example = {
          maxConcurrent = 16;
        };
        description = ''
          ~/.pi/agent/subagents.json: pi-subagents' machine-wide settings
          (concurrency, turn limits, cost display, ...); a project's own
          `.pi/subagents.json` still overrides it. Only written when not empty.
        '';
      };
    };

    orchestration = {
      enable = mkOption {
        type = types.bool;
        default = cfg.subagents.enable;
        defaultText = lib.literalExpression "config.programs.pi-agent.subagents.enable";
        description = ''
          Multi-agent working: tells the main agent when and how to hand work to
          subagents (~/.pi/agent/APPEND_SYSTEM.md) and installs the default agents
          (explorer, implementer with Go/Kotlin/Nix/Ansible variants, reviewer).
        '';
      };
      instructions = mkOption {
        type = types.lines;
        default = orchestration.instructions;
        defaultText = lib.literalMD "the text in [orchestration.nix](./orchestration.nix)";
        description = "What the main agent is told about delegating; replace it to change the policy.";
      };
    };

    agents = mkOption {
      type = types.attrsOf agentType;
      default = { };
      example = lib.literalExpression ''
        {
          explorer.model = "haiku";              # cheaper model for exploration
          go-implementer.frontmatter.isolation = "worktree";
          security-auditor = {
            description = "Reviews changes for security problems";
            tools = "read, grep, find";
            prompt = "You are a security auditor. ...";
          };
        }
      '';
      description = ''
        Agents the main agent can spawn, by name (~/.pi/agent/agents/<name>.md).
        With `orchestration.enable` the defaults are there already and can be
        tuned one field at a time; add your own here.
      '';
    };

    lsp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "pi-lsp (diagnostics after each edit) and ~/.pi/agent/lsp.json for it.";
      };
      ansibleDirs = mkOption {
        type = types.listOf types.str;
        default = [
          "ansible"
          "playbooks"
          "roles"
          "group_vars"
          "host_vars"
          "inventories"
        ];
        description = ''
          Directory names whose YAML is Ansible: routed to the Ansible language
          server and kept away from the plain YAML one.
        '';
      };
      servers = mkOption {
        type = serverType;
        default = { };
        description = ''
          Language servers by id, in pi-lsp's format. Defaults: Go, Nix, YAML,
          Ansible, Bash and (on x86_64-linux) Kotlin. Turn one off with
          `servers.<id>.enabled = false;`.
        '';
      };
    };

    autoModel = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          pi-auto-model: routes each task to a suitable model among those Pi
          has credentials for (a virtual `pi-auto-model/auto` model).
        '';
      };
      settings = mkOption {
        inherit (jsonFormat) type;
        default = { };
        example = {
          policy = "balanced";
          pricing.litellm.enabled = false;
        };
        description = ''
          Contents of ~/.pi/agent/auto-model.json (see the extension's
          README); the file is only written when this is not empty. Note the
          extension refreshes a price catalog from GitHub daily unless
          `pricing.litellm.enabled = false`.
        '';
      };
    };

    guard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "The guard extension (./guard/guard.ts); see its header for the built-in rules.";
      };
      lockedFiles = mkOption {
        type = types.listOf types.str;
        default = [
          "flake.lock"
          "go.sum"
        ];
        description = "File names the model may not write or edit by hand (replaces the default list).";
      };
      secretPathPatterns = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "\\.env$" ];
        description = "More JavaScript regexes for paths the model may not read or write, on top of the built-in ones.";
      };
      blockCommands = mkOption {
        type = types.listOf ruleType;
        default = [ ];
        description = "Commands that are always refused, in addition to the built-in rules.";
      };
      confirmCommands = mkOption {
        type = types.listOf ruleType;
        default = [ ];
        description = "Commands that need a yes from the user, in addition to the built-in rules.";
      };
    };

    context = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = ''
        Instructions for every session: written to ~/.pi/agent/AGENTS.md.
        Leave null if you keep your own.
      '';
    };

    skills = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Skills (directories with a SKILL.md) linked into ~/.pi/agent/skills/<name>.";
    };

    models = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = lib.literalExpression ''
        {
          providers.internal = {
            baseUrl = "https://llm.example.com/v1";
            api = "openai-completions";
            apiKey = "!cat ~/.config/internal-llm-key";
            models = [ { id = "some-model"; } ];
          };
        }
      '';
      description = ''
        Contents of ~/.pi/agent/models.json (custom endpoints and models); only
        written when not empty. Pi's own providers, including the Cloudflare AI
        Gateway, need no entry here: set `env` for the account and gateway IDs.
      '';
    };

    settingsDefaults = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        defaultProvider = "cloudflare-ai-gateway";
      };
      description = ''
        Keys for ~/.pi/agent/settings.json that are set when missing and never
        overwritten afterwards, so Pi (or the user, with /settings) stays in
        charge of them once they exist.
      '';
    };

    zed.enable = mkEnableOption "Pi as an agent server in Zed (via pi-acp); needs programs.zed-editor";
  };

  config = lib.mkIf cfg.enable {
    programs.pi-agent = {
      lsp.servers = asDefaults defaultLspServers;
      mcp.servers = asDefaults defaultMcpServers;
      subagents.settings = {
        # Say which model each agent runs on and what it costs; useful the
        # moment models are routed automatically or a gateway bills you.
        showModel = lib.mkDefault true;
        showCost = lib.mkDefault true;
      };
      agents = lib.optionalAttrs cfg.orchestration.enable (
        lib.mapAttrs (_: a: lib.mapAttrs (_: lib.mkDefault) a) orchestration.agents
      );
    };

    home.packages = [ cfg.package ];

    home.file =
      writeIfSet ".pi/agent/auto-model.json" (
        lib.optionalAttrs cfg.autoModel.enable cfg.autoModel.settings
      )
      // writeIfSet ".pi/agent/models.json" cfg.models
      // lib.optionalAttrs cfg.lsp.enable {
        ".pi/agent/lsp.json".source = toFile "lsp.json" {
          version = 1;
          servers = lib.mapAttrsToList (id: s: { inherit id; } // s) cfg.lsp.servers;
        };
      }
      // lib.optionalAttrs cfg.guard.enable {
        ".pi/agent/extensions/guard.ts".source = ./guard/guard.ts;
        ".pi/agent/guard.json".source = toFile "guard.json" {
          inherit (cfg.guard)
            lockedFiles
            secretPathPatterns
            blockCommands
            confirmCommands
            ;
        };
      }
      // lib.optionalAttrs (cfg.subagents.enable && cfg.subagents.settings != { }) {
        ".pi/agent/subagents.json".source = toFile "subagents.json" cfg.subagents.settings;
      }
      // lib.optionalAttrs (cfg.subagents.enable && cfg.orchestration.enable) {
        ".pi/agent/APPEND_SYSTEM.md".text = cfg.orchestration.instructions;
      }
      // lib.optionalAttrs cfg.subagents.enable (
        lib.mapAttrs' (name: a: lib.nameValuePair ".pi/agent/agents/${name}.md" { text = agentFile a; }) (
          lib.filterAttrs (_: a: a.enable) cfg.agents
        )
      )
      // lib.optionalAttrs (cfg.context != null) {
        ".pi/agent/AGENTS.md".text = cfg.context;
      }
      // lib.mapAttrs' (
        name: path: lib.nameValuePair ".pi/agent/skills/${name}" { source = path; }
      ) cfg.skills;

    xdg.configFile = lib.optionalAttrs (cfg.mcp.enable && cfg.mcp.servers != { }) {
      "mcp/mcp.json".source = toFile "mcp.json" {
        mcpServers = cfg.mcp.servers;
      };
    };

    home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] settingsMerge;

    # pi-acp is an ACP bridge that Zed talks JSON-RPC to over stdio and that
    # spawns `pi --mode rpc`; it is wrapped so that `pi` is this configuration's.
    # Declared here rather than through Zed's ACP registry UI, which would write
    # an entry that home-manager overwrites at the next switch.
    programs.zed-editor.userSettings = lib.mkIf cfg.zed.enable {
      agent_servers.pi-acp = {
        type = "custom";
        command = lib.getExe (
          pkgs.symlinkJoin {
            name = "pi-acp-${ext.pi-acp.version}";
            paths = [ ext.pi-acp ];
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            postBuild = ''
              wrapProgram $out/bin/pi-acp --prefix PATH : ${cfg.package}/bin
            '';
            inherit (ext.pi-acp) meta;
          }
        );
        args = [ ];
        env = { };
      };
    };
  };
}
