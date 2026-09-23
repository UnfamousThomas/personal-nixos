{
  flake.modules.homeManager.discord =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.vesktop ]; # Vesktop: better Wayland/screenshare support than stock Discord
    };
}
