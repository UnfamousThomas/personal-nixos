{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently.
  flake.overlays.default = final: _prev: {
    sony-device-center = final.callPackage ../../pkgs/sony-device-center.nix { };
    gradient-wallpaper = final.callPackage ../../pkgs/gradient-wallpaper.nix { };
  };
}
