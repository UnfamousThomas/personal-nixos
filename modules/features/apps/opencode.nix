{
  # opencode CLI + shared config, installed from upstream's own flake
  # (github:sst/opencode) via the overlay in modules/flake/overlays.nix --
  # deliberately not nixpkgs' `opencode` package (lags releases).
  # Update: `nix flake lock --update-input opencode`.
  # Shared config lives in ~/.config/opencode/opencode.json, which the CLI
  # and every frontend (Zed, TUI, desktop) both read, so this covers them all.
  # oh-my-opencode-slim (github:alvinunreal/oh-my-opencode-slim) is an npm
  # plugin: opencode Bun-installs it at startup into
  # ~/.cache/opencode/node_modules, so no extra flake input is needed. It is
  # registered in `plugin` below; pin with "oh-my-opencode-slim@<version>"
  # for reproducible versions. Its own config is
  # ~/.config/opencode/oh-my-opencode-slim.json (see below).
  flake.modules.homeManager.opencode =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.opencode ];

      home.sessionVariables = {
        # oh-my-opencode-slim's default background-orchestration workflow
        # relies on opencode's native background subagents.
        OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
        # Enables opencode's built-in websearch tool (used by the librarian
        # agent) without an API key.
        OPENCODE_ENABLE_EXA = "1";
      };

      # opencode core config (~/.config/opencode/opencode.json).
      xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        model = "openrouter/auto";
        provider.openrouter.models.auto = {
          name = "OpenRouter Auto";
        };
        plugin = [ "oh-my-opencode-slim" ];
        mcp.linear = {
          type = "remote";
          url = "https://mcp.linear.app/mcp";
        };
      };

      # oh-my-opencode-slim config: every agent pinned to openrouter/auto,
      # matching the top-level `model` above.
      xdg.configFile."opencode/oh-my-opencode-slim.json".text = builtins.toJSON {
        "$schema" = "https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json";
        preset = "openrouter";
        presets.openrouter = {
          orchestrator = {
            model = "openrouter/auto";
          };
          oracle = {
            model = "openrouter/auto";
          };
          librarian = {
            model = "openrouter/auto";
          };
          explorer = {
            model = "openrouter/auto";
          };
          designer = {
            model = "openrouter/auto";
          };
          fixer = {
            model = "openrouter/auto";
          };
        };
      };
    };
}
