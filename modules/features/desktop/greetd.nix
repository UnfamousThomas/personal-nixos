{
  flake.modules.nixos.desktop-greetd =
    { pkgs, ... }:
    {
      services.greetd = {
        enable = true;
        # niri-session runs niri as a systemd user service and starts
        # graphical-session.target, which portals, XDG autostart (e.g.
        # blueman-applet) and Noctalia's user service hang off.
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --cmd niri-session";
      };
    };
}
