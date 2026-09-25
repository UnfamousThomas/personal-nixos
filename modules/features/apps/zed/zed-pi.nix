{
  # Pi as an agent server in Zed, through pi-acp. What that means and why it is
  # declared rather than added from Zed's ACP registry UI is in pi/home-module.nix.
  flake.modules.homeManager.zed-pi = {
    programs.pi-agent.zed.enable = true;
  };
}
