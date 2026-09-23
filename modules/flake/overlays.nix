{ inputs, ... }:
{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently.
  flake.overlays.default = final: _prev: {
    sony-device-center = final.callPackage ../../pkgs/sony-device-center.nix { };
    gradient-wallpaper = final.callPackage ../../pkgs/gradient-wallpaper.nix { };

    # Upstream's test suite includes a case that spawns a bwrap sandbox and
    # tries to configure a loopback interface inside it -- needs network
    # namespace privileges a Nix build sandbox (and GitHub Actions' runner)
    # doesn't grant, so it fails there regardless of whether the code under
    # test is actually broken. Skip tests for the packaged build; they still
    # run in upstream's own CI, which does have those privileges.
    openwave = inputs.openwave.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
      doCheck = false;
    });
  };
}
