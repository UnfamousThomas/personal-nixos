{
  # Package itself is defined in pkgs/sony-device-center.nix and applied via
  # the flake's overlay (modules/flake/overlays.nix), so it's just
  # pkgs.sony-device-center here like any other package.
  flake.modules.homeManager.sony-device-center =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.sony-device-center ];
    };
}
