{
  # Native opencode from upstream's own flake (github:sst/opencode) --
  # deliberately not nixpkgs' `opencode` package (lags releases) and not
  # opencode-alpine-box (github:grigio/opencode-alpine-box is built for
  # interactive `docker run -ti` sessions with no documented headless/stdio
  # mode; Zed's ACP transport needs a local process it can exec and talk
  # JSON-RPC to over stdin/stdout, which the box doesn't cleanly offer).
  # Update: `nix flake lock --update-input opencode`. The package itself is
  # `pkgs.opencode` (modules/flake/overlays.nix), which skips upstream's
  # build-time smoke test -- see the comment there for why.
  flake.modules.homeManager.zed-opencode =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.opencode ];

      programs.zed-editor.userSettings.agent_servers.opencode = {
        type = "custom";
        command = "${pkgs.opencode}/bin/opencode";
        args = [ "acp" ];
        env = { };
      };

      # opencode's own config (~/.config/opencode/opencode.json).
      xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        mcp.linear = {
          type = "remote";
          url = "https://mcp.linear.app/mcp";
        };
      };
    };
}
