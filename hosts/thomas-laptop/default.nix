{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos.thomas-laptop =
    { config, ... }:
    {
      imports = [
        nixos.base
        nixos.workstation
        nixos.gaming-minecraft
        nixos.laptop
        ./disko.nix
      ];

      hardware.facter.reportPath = ./facter.json;

      # disko's resumeDevice=true (disko.nix) only sets boot.resumeDevice;
      # the actual kernel resume= parameter still has to be set by hand.
      boot.kernelParams = [ "resume=/dev/mapper/cryptswap" ];

      # Set once, at first install, and never bumped afterwards -- these
      # tell NixOS/Home Manager which stateful defaults to preserve across
      # upgrades; they are not a "target version".
      system.stateVersion = "26.05";
      home-manager.users.${config.my.user}.home.stateVersion = "26.05";
    };
}
