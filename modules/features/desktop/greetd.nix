{
  flake.modules.nixos.desktop-greetd =
    { pkgs, ... }:
    {
      services.greetd = {
        enable = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --cmd niri";
      };
    };
}
