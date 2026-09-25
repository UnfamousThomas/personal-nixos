{
  # Pi coding agent (pi.dev) with its extensions, LSP servers, MCP servers and
  # guard, all declared here; nothing is installed with `pi install` or npm.
  #
  #   pi                   pkgs.pi-agent: the agent, with language servers and
  #                        linters on PATH (pkgs/pi-agent.nix)
  #   extensions           built from pinned sources (pkgs/pi-extensions.nix)
  #                        and listed in ~/.pi/agent/settings.json `packages`
  #   ~/.pi/agent/lsp.json pi-lsp servers (read-only, from Nix)
  #   ~/.config/mcp/mcp.json  servers for pi-mcp-adapter (read-only, from Nix)
  #   ~/.pi/agent/extensions/guard.ts  permission guard (pi/guard.ts)
  #
  # Not set up here on purpose: model providers and credentials (Pi's own
  # ~/.pi/agent/auth.json / models.json, written by Pi and left alone).
  # Zed is wired in zed/zed-pi.nix.
  flake.modules.homeManager.pi =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      ext = pkgs.piExtensions;

      # Both extensions and settings.json paths are absolute store paths, so a
      # rebuild swaps them atomically with the generation.
      packages = map ext.extensionPath [
        ext.pi-mcp-adapter
        ext.pi-subagents
        ext.pi-lsp
      ];

      # gh's token, fetched when the server starts, so nothing secret is
      # stored in the config; needs a prior `gh auth login`.
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

      # Servers are matched by file glob (relative to the workspace); the root
      # of each is the nearest dir with one of rootMarkers. Bare `bin` names
      # resolve through PATH, so a project's devenv toolchain wins over the
      # copies in pkgs/pi-agent.nix.
      server =
        id: bin: args: extra:
        {
          inherit id bin args;
          enabled = true;
          cwd = "{root}";
        }
        // extra;
      # YAML that belongs to Ansible: anything under these directories. Globs
      # match paths relative to the directory Pi was started in, so a bare
      # `playbooks/` works from inside an ansible/ dir as well as above it.
      ansibleGlobs =
        lib.concatMap
          (dir: [
            "**/${dir}/**/*.yaml"
            "**/${dir}/**/*.yml"
          ])
          [
            "ansible"
            "playbooks"
            "roles"
            "group_vars"
            "host_vars"
            "inventories"
          ];

      lsp = {
        version = 1;
        servers = [
          (server "gopls" "gopls" [ ] {
            include = [ "**/*.go" ];
            rootMarkers = [
              "go.work"
              "go.mod"
            ];
            languageIdByExtension.".go" = "go";
            startupTimeoutMs = 60000;
            diagnosticsWaitMs = 3000;
          })
          # Alpha, and a JVM: imports the Gradle project on first use, so give
          # it far longer than the others. Needs the project's Gradle/JDK,
          # i.e. run Pi inside the project's devenv shell.
          (server "kotlin-lsp" "kotlin-lsp" [ "--stdio" ] {
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
          })
          (server "nixd" "nixd" [ ] {
            include = [ "**/*.nix" ];
            rootMarkers = [
              "flake.nix"
              ".git"
            ];
            languageIdByExtension.".nix" = "nix";
            diagnosticsWaitMs = 3000;
          })
          # YAML that isn't Ansible; Ansible files go to the server below so
          # they don't get both (and the wrong schemas).
          (server "yaml" "yaml-language-server" [ "--stdio" ] {
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
          })
          # Ansible files (see ansibleGlobs) under a directory with an
          # ansible.cfg (Mirror's infra/platform/ansible). Its linting shells
          # out to ansible-lint.
          (server "ansible" "ansible-language-server" [ "--stdio" ] {
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
          })
          # Runs shellcheck for diagnostics.
          (server "bash" "bash-language-server" [ "start" ] {
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
          })
        ];
      };

      # pi-mcp-adapter connects lazily, on the first call to a server's tools.
      mcp.mcpServers = {
        # Needs a Go toolchain (from the project's devenv) at call time.
        gopls = {
          command = "gopls";
          args = [ "mcp" ];
        };
        nixos.command = lib.getExe pkgs.mcp-nixos;
        github.command = lib.getExe github-mcp;
        # Drives a Minestom test server. Bot name and address are the defaults
        # for a local dev server; see pkgs/minecraft-mcp-server.nix for the
        # supported Minecraft versions.
        minecraft = {
          command = lib.getExe pkgs.minecraft-mcp-server;
          args = [
            "--host"
            "localhost"
            "--port"
            "25565"
            "--username"
            "PiBot"
          ];
        };
      };
    in
    {
      home.packages = [ pkgs.pi-agent ];

      home.file = {
        ".pi/agent/lsp.json".text = builtins.toJSON lsp;
        ".pi/agent/extensions/guard.ts".source = ./pi/guard.ts;
      };
      xdg.configFile."mcp/mcp.json".text = builtins.toJSON mcp;

      # Pi writes its own state into settings.json (default model, last
      # changelog seen, ...), so it can't be a read-only Nix file. Instead
      # replace just the `packages` entries that point into the Nix store with
      # this generation's, leaving every other key -- and any package added by
      # hand -- alone. A file that isn't valid JSON is left untouched.
      home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [[ ! -v DRY_RUN ]]; then
          settings="${config.home.homeDirectory}/.pi/agent/settings.json"
          mkdir -p "$(dirname "$settings")"
          [ -e "$settings" ] || echo '{}' > "$settings"
          if merged="$(${lib.getExe pkgs.jq} --argjson ours '${builtins.toJSON packages}' '
              .packages = (
                ((.packages // [])
                  | map(select((if type == "object" then .source else . end)
                               | startswith("/nix/store/") | not)))
                + $ours)' "$settings")"; then
            # Compare parsed, not textually: Pi formats the file its own way.
            if [ "$(${lib.getExe pkgs.jq} -cS . <<< "$merged")" != "$(${lib.getExe pkgs.jq} -cS . "$settings")" ]; then
              cp "$settings" "$settings.hm-backup"
              printf '%s\n' "$merged" > "$settings"
            fi
          else
            echo "pi: $settings is not valid JSON; not updating its packages" >&2
          fi
        fi
      '';
    };
}
