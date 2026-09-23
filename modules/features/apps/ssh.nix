{
  flake.modules.homeManager.ssh = {
    # The default IdentityAgent (1Password's socket) is set in
    # onepassword.nix, since it depends on that feature being enabled.
    # ssh offers whatever keys the agent holds. To pin one key for GitHub,
    # save its *public* half as e.g. ~/.ssh/github.pub and set
    # settings."github.com" = { IdentitiesOnly = true; IdentityFile = "~/.ssh/github.pub"; };
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };
  };
}
