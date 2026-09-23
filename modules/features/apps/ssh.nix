{
  flake.modules.homeManager.ssh = {
    # The default IdentityAgent (1Password's socket) is set in
    # onepassword.nix, since it depends on that feature being enabled.
    programs.ssh = {
      enable = true;
      matchBlocks."github.com".identitiesOnly = true;
    };
  };
}
