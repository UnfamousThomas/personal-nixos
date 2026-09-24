{
  # Wire opencode into Zed as an agent server. opencode itself (binary +
  # ~/.config/opencode/opencode.json) is managed by the `opencode` module
  # (modules/features/apps/opencode.nix).
  # Zed's ACP transport needs a local process it can exec and talk JSON-RPC
  # to over stdin/stdout, which opencode's `acp` mode provides.
  flake.modules.homeManager.zed-opencode =
    { pkgs, ... }:
    {
      programs.zed-editor.userSettings.agent_servers.opencode = {
        type = "custom";
        command = "${pkgs.opencode}/bin/opencode";
        args = [ "acp" ];
        env = { };
      };
    };
}
