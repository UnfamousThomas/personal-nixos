{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  flake.modules.nixos.laptop =
    { config, ... }:
    {
      imports = [ nixos.laptop-power ];
      home-manager.users.${config.my.user}.imports = [ homeManager.laptop-touchpad ];
    };
}
