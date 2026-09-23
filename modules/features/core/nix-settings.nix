{
  flake.modules.nixos.core-nix = { inputs, ... }: {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "thomas"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
      ];
      # cache.nixos.org's key is one of Nix's own built-in defaults; listed
      # explicitly for clarity. The other two are verified against each
      # cache's published Cachix signing key -- see README for how to
      # re-verify if either project ever rotates keys.
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

    # Unfree is required system-wide: Steam, Discord, 1Password, NVIDIA,
    # Lunar Client and others are all unfree. Applied here once so every
    # consumer (NixOS itself, and Home Manager via useGlobalPkgs) inherits it.
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [ inputs.self.overlays.default ];

    # Set once, at first install, and never bumped afterwards.
    system.stateVersion = "26.05";
  };
}
