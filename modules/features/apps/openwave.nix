{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # OpenWave (Elgato Wave XLR control) ships its own maintained flake --
  # used directly rather than re-packaged. To update: bump the `openwave`
  # flake input (`nix flake update openwave`). The package itself is
  # `pkgs.openwave` (modules/flake/overlays.nix), which disables upstream's
  # test suite -- see the comment there for why.
  #
  # The NixOS module installs the package's udev rules (non-root USB access
  # to the device) and the app for the user.
  flake.modules.nixos.openwave =
    { config, pkgs, ... }:
    {
      services.udev.packages = [ pkgs.openwave ];
      home-manager.users.${config.my.user}.imports = [ homeManager.openwave ];
    };

  flake.modules.homeManager.openwave =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.openwave ];
    };
}
