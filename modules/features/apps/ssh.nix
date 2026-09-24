{
  flake.modules.homeManager.ssh = {
    # The default IdentityAgent (1Password's socket) is set in
    # onepassword.nix, since it depends on that feature being enabled.
    # ssh offers whatever keys the agent holds. github.com is pinned to the
    # agenix-decrypted key in mirror-repos.nix when secrets/mirror-ssh.age exists.
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };
  };
}
