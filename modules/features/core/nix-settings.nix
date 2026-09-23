{ inputs, ... }:
{
  flake.modules.nixos.core-nix =
    { config, ... }:
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # Trusting the user lets devenv/nix use per-project caches without
        # sudo. It also makes that user root-equivalent (it can pass
        # --option to the daemon), as does the docker group -- see
        # features/apps/docker.nix.
        trusted-users = [
          "root"
          config.my.user
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://noctalia.cachix.org"
        ];
        # cache.nixos.org's key is one of Nix's own built-in defaults; listed
        # explicitly for clarity. The other two are verified against each
        # cache's published Cachix signing key -- see README "Binary cache
        # keys" for how to re-verify if either project ever rotates keys.
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nix.optimise.automatic = true;

      # Unfree is required system-wide: Steam, 1Password, Lunar Client and
      # others are all unfree. Applied here once so every consumer (NixOS
      # itself, and Home Manager via useGlobalPkgs) inherits it.
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ inputs.self.overlays.default ];
    };
}
