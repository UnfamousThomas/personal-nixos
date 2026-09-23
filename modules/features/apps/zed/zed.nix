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
    { pkgs, ... }:
    {
      programs.zed-editor = {
        enable = true;
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

        # Theme and font are deliberately NOT set here: Stylix ships its own
        # Zed target (github:tinted-theming/base16-zed) that themes Zed
        # from the same base16Scheme/fonts as everything else -- setting
        # them here too collided with it (buffer_font_size ended up with
        # two conflicting definitions and failed to evaluate). One source
        # of truth for theming beats a hardcoded "Catppuccin Mocha" extension
        # name that could drift from the actual palette anyway.
        userSettings = {
          telemetry = {
            metrics = false;
            diagnostics = false;
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

          formatter = "prettier";
        };
      };
    };
}
