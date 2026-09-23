{ inputs, config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # OpenWave (Elgato Wave XLR control) ships its own maintained flake --
  # used directly rather than re-packaged. To update: bump the `openwave`
  # flake input (`nix flake update openwave`).
  #
  # The NixOS module installs the package's udev rules (non-root USB access
  # to the device) and the app for the user.
  flake.modules.nixos.openwave =
    { config, pkgs, ... }:
    {
      services.udev.packages = [ inputs.openwave.packages.${pkgs.stdenv.hostPlatform.system}.default ];
      home-manager.users.${config.my.user}.imports = [ homeManager.openwave ];
    };

  flake.modules.homeManager.openwave =
    { pkgs, ... }:
    {
      home.packages = [ inputs.openwave.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };
}
