{ inputs, ... }:
{
  # Native opencode from upstream's own flake (github:sst/opencode) --
  # deliberately not nixpkgs' `opencode` package (lags releases) and not
  # opencode-alpine-box (github:grigio/opencode-alpine-box is built for
  # interactive `docker run -ti` sessions with no documented headless/stdio
  # mode; Zed's ACP transport needs a local process it can exec and talk
  # JSON-RPC to over stdin/stdout, which the box doesn't cleanly offer).
  # Update: `nix flake lock --update-input opencode`.
  flake.modules.homeManager.zed-opencode =
    { pkgs, ... }:
    let
      opencode = inputs.opencode.packages.${pkgs.system}.opencode;
    in
    {
      home.packages = [ opencode ];

      programs.zed-editor.userSettings.agent_servers.opencode = {
        type = "custom";
        command = "${opencode}/bin/opencode";
        args = [ "acp" ];
        env = { };
      };
    };
}
