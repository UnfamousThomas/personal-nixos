{ inputs, config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.core-home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true; # reuse the system's nixpkgs instance (one allowUnfree/overlay source of truth)
      backupFileExtension = "hm-backup";
      sharedModules = [
        homeManager.core-options
        # Ready for when a per-user secret is actually needed (see
        # secrets.nix / README "Secrets"). Decrypts with a dedicated,
        # unencrypted age key, since the agenix user service runs
        # non-interactively.
        inputs.agenix.homeManagerModules.default
        (
          { config, ... }:
          {
            age.identityPaths = [ "${config.xdg.configHome}/age/keys.txt" ];
          }
        )
      ];
    };
  };
}
