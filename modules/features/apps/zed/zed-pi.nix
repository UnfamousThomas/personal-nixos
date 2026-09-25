{
  # Wire Pi into Zed as an agent server through pi-acp, an ACP (Agent Client
  # Protocol) bridge that Zed talks JSON-RPC to over stdin/stdout and that in
  # turn spawns `pi --mode rpc`. Pi itself, its extensions and config come
  # from the `pi` module (modules/features/apps/pi.nix).
  # This is declared here rather than added through Zed's ACP registry UI,
  # which would write a `"type": "registry"` entry that home-manager
  # overwrites at the next switch.
  flake.modules.homeManager.zed-pi =
    { lib, pkgs, ... }:
    let
      # pi-acp runs whatever `pi` is on its PATH; make that the wrapped one
      # (language servers, linters and MCP support included) rather than
      # relying on Zed's environment.
      pi-acp = pkgs.symlinkJoin {
        name = "pi-acp-${pkgs.piExtensions.pi-acp.version}";
        paths = [ pkgs.piExtensions.pi-acp ];
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        postBuild = ''
          wrapProgram $out/bin/pi-acp --prefix PATH : ${pkgs.pi-agent}/bin
        '';
        inherit (pkgs.piExtensions.pi-acp) meta;
      };
    in
    {
      programs.zed-editor.userSettings.agent_servers.pi-acp = {
        type = "custom";
        command = lib.getExe pi-acp;
        args = [ ];
        env = { };
      };
    };
}
