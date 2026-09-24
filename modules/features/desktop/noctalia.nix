{ inputs, ... }:
{
  flake.modules.nixos.desktop-noctalia =
    { pkgs, ... }:
    {
      imports = [ inputs.noctalia.nixosModules.default ];
      programs.noctalia = {
        enable = true;
        package = pkgs.noctalia; # the patched build, modules/flake/overlays.nix
        recommendedServices.enable = true; # NetworkManager, Bluetooth, UPower, power-profiles-daemon
      };
    };

  # Theme and wallpaper come from Stylix's Noctalia target (desktop/stylix.nix).
  flake.modules.homeManager.noctalia =
    { pkgs, ... }:
    {
      imports = [ inputs.noctalia.homeModules.default ];
      programs.noctalia = {
        enable = true;
        package = pkgs.noctalia; # the patched build, modules/flake/overlays.nix
        # User service bound to graphical-session.target (started by
        # niri-session).
        systemd.enable = true;
        # Declarative defaults (still overridable at runtime via Settings --
        # see the home-module's own note on that).
        settings = {
          # Icon only: show_label controls both the interface name
          # (enp0s31f6) on wired and the SSID on Wi-Fi.
          widget.network.show_label = false;

          # The clock is the one widget meant to stand out: bigger text, on
          # a capsule, in the accent color.
          widget.clock = {
            font_scale = 1.3;
            capsule = true;
            capsule_fill = "surface_variant";
            color = "primary";
            tooltip_format = "{:%A, %d %B %Y}";
          };

          # The wallpaper panel's Dark/Light/Auto switcher is hidden
          # (overlays.nix), so the mode is fixed here.
          theme.mode = "dark";

          # The picker browses one directory (~/Pictures by default, empty on
          # a fresh install): the generated gradients, pkgs/gradient-wallpaper.nix.
          wallpaper.directory = "${pkgs.gradient-wallpaper}/share/wallpapers";
        };
      };
    };
}
