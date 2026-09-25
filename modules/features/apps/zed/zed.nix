{
  # Follows https://wiki.nixos.org/wiki/Zed's "bring your own LSP servers"
  # approach: language servers installed via extraPackages (into Zed's own
  # PATH), with `binary.path_lookup = true` per-server so Zed prefers them
  # over auto-downloading its own (which fail to run on NixOS due to
  # dynamic linking). Full toolchains (a JDK, a Go compiler, node, ansible
  # itself) intentionally are NOT installed here -- those come from
  # per-project devenv shells, per the "keep this config minimal" goal.
  # Exception: gopls genuinely shells out to `go` at runtime for module
  # resolution, so it has degraded functionality outside a devenv shell
  # that provides a Go toolchain -- that's an accepted trade-off, not an
  # oversight.
  flake.modules.homeManager.zed =
    { lib, pkgs, ... }:
    {
      # Zed's own theme and fonts are set below. Stylix's generated theme is
      # rejected by current Zed (`appearance: "unspecified"`), so it never
      # loaded and Zed silently fell back to its default.
      stylix.targets.zed.enable = false;

      programs.zed-editor = {
        enable = true;
        # Zed installs these itself on first start.
        extensions = [
          "intellij-newui-theme"
          "jetbrains-new-ui-icons"
        ];
        extraPackages = with pkgs; [
          jdt-language-server
          kotlin-language-server
          gopls
          gofumpt
          typescript-language-server
          vscode-langservers-extracted
          tailwindcss-language-server
          yaml-language-server
          ansible-language-server
          ansible-lint
          prettierd
        ];

        # Theme and fonts are set below (Stylix's Zed target is off above).
        userSettings = {
          telemetry = {
            metrics = false;
            diagnostics = false;
          };

          # --- JetBrains-style layout ---------------------------------
          # JetBrains keymap (Ctrl+Shift+A find action, Ctrl+B, Alt+1 for
          # the project panel, ...), IntelliJ New UI theme and icons.
          base_keymap = "JetBrains";
          theme = "JetBrains New Dark";
          icon_theme = "JetBrains New UI Icons (Dark)";
          buffer_font_family = "JetBrainsMono Nerd Font Mono";
          buffer_font_size = 14;
          buffer_line_height.custom = 1.4;
          ui_font_size = 14;

          # "Tool windows": Project, Structure and Commit on the left,
          # Terminal and Debug at the bottom, the AI agent on the right.
          project_panel = {
            dock = "left";
            auto_reveal_entries = true; # follow the open file, like "Always Select Opened File"
            git_status = true;
            file_icons = true;
            folder_icons = true;
            indent_size = 16;
          };
          outline_panel.dock = "left"; # Structure
          git_panel.dock = "left"; # Commit
          terminal.dock = "bottom";
          debugger.dock = "bottom";
          agent.dock = "right";

          tabs = {
            file_icons = true;
            git_status = true;
            show_diagnostics = "errors";
            close_position = "right";
          };
          minimap.show = "auto";
          inlay_hints.enabled = true;
          git.inline_blame.enabled = true;

          # Claude Code as the agent (the adapter from nixpkgs already points
          # at nixpkgs' claude-code). Declared here rather than added from
          # Zed's agent UI, which would write an entry home-manager
          # overwrites at the next switch.
          agent_servers.claude-acp = {
            type = "custom";
            command = lib.getExe pkgs.claude-agent-acp;
            args = [ ];
            env = { };
          };

          lsp = {
            jdtls.binary.path_lookup = true;
            kotlin-language-server.binary.path_lookup = true;
            gopls.binary.path_lookup = true;
            typescript-language-server.binary.path_lookup = true;
            vscode-json-language-server.binary.path_lookup = true;
            vscode-css-language-server.binary.path_lookup = true;
            vscode-html-language-server.binary.path_lookup = true;
            tailwindcss-language-server.binary.path_lookup = true;
            ansible-language-server.binary.path_lookup = true;
            yaml-language-server = {
              binary.path_lookup = true;
              settings.yaml = {
                schemas.kubernetes = "*.k8s.yaml";
                # Bump alongside whatever cluster version you're targeting.
                kubernetesVersion = "1.31.0";
              };
            };
          };

          # Web/config languages format with the prettierd installed above;
          # everything else formats with its language server. TS/JS use the
          # typescript-language-server installed above, not vtsls.
          languages =
            let
              prettierd = {
                formatter.external = {
                  command = "prettierd";
                  arguments = [ "{buffer_path}" ];
                };
              };
              tsServers = {
                language_servers = [
                  "typescript-language-server"
                  "!vtsls"
                  "..."
                ];
              };
            in
            {
              TypeScript = prettierd // tsServers;
              TSX = prettierd // tsServers;
              JavaScript = prettierd // tsServers;
              JSON = prettierd;
              CSS = prettierd;
              HTML = prettierd;
              YAML = prettierd;
            };
        };
      };
    };
}
