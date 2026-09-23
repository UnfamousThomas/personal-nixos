{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  # Graphical desktop and everyday apps.
  flake.modules.nixos.workstation =
    { config, ... }:
    {
      imports = with nixos; [
        security-idcard
        desktop-niri
        desktop-greetd
        desktop-noctalia
        desktop-stylix
        desktop-bluetooth
        desktop-audio
        firefox
        onepassword
        docker
        tailscale
      ];
      home-manager.users.${config.my.user}.imports = [ homeManager.workstation ];
    };

  flake.modules.homeManager.workstation.imports = with homeManager; [
    ghostty
    niri
    noctalia
    firefox
    onepassword
    devenv
    zed
    zed-opencode
    discord
    sony-device-center
    hidden-apps
  ];
}
