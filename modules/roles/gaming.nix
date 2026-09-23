{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  flake.modules.nixos.gaming =
    { config, ... }:
    {
      imports = [ nixos.steam ];
      home-manager.users.${config.my.user}.imports = [ homeManager.gaming ];
    };

  flake.modules.homeManager.gaming.imports = with homeManager; [
    minecraft
    mangohud
  ];
}
