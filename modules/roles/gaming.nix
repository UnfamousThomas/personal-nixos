{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  # Split from Minecraft so a host can have one without the other
  # (thomas-laptop keeps Minecraft, drops Steam/Proton).
  flake.modules.nixos.gaming-steam =
    { config, ... }:
    {
      imports = [ nixos.steam ];
      home-manager.users.${config.my.user}.imports = [ homeManager.mangohud ];
    };

  flake.modules.nixos.gaming-minecraft =
    { config, ... }:
    {
      home-manager.users.${config.my.user}.imports = with homeManager; [
        minecraft
        mangohud
      ];
    };
}
