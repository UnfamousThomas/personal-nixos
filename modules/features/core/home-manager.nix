{ inputs, ... }:
{
  flake.modules.nixos.core-home-manager =
    { config, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager = {
        useGlobalPkgs = true; # reuse the system's nixpkgs instance (one allowUnfree/overlay source of truth)
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {
          inherit inputs;
        };
        # Ready for when a per-user secret is actually needed (see
        # secrets.nix / README "Secrets" section) -- decrypts against the
        # user's own SSH key, not the host key.
        sharedModules = [
          inputs.agenix.homeManagerModules.default
          { age.identityPaths = [ "${config.users.users.thomas.home}/.ssh/id_ed25519" ]; }
        ];
      };

      # Set once, at first install, and never bumped afterwards -- this is
      # what tells Home Manager which defaults to preserve across upgrades,
      # not a "target version."
      home-manager.users.thomas.home.stateVersion = "26.05";
    };
}
