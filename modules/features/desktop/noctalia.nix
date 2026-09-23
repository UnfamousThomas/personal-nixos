{ inputs, ... }:
{
  flake.modules.nixos.desktop-noctalia = {
    imports = [ inputs.noctalia.nixosModules.default ];
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true; # NetworkManager, Bluetooth, UPower, power-profiles-daemon
    };
  };

  # Theme and wallpaper come from Stylix's Noctalia target (desktop/stylix.nix).
  flake.modules.homeManager.noctalia = {
    imports = [ inputs.noctalia.homeModules.default ];
    programs.noctalia = {
      enable = true;
      # User service bound to graphical-session.target (started by
      # niri-session).
      systemd.enable = true;
    };
  };
}
