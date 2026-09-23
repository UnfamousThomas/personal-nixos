{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos.thomas-desktop =
    { config, lib, ... }:
    {
      imports = [
        nixos.base
        nixos.workstation
        nixos.gaming
        nixos.openwave
        ./disko.nix
      ];

      options.host.bulkDisk.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether the 1TB bulk HDD (./disko-bulk.nix) is part of this host.
          Set to false to install onto the SSD alone; see README "Adding the
          bulk disk later" for bringing it in afterwards.
        '';
      };

      config = lib.mkMerge [
        {
          hardware.facter.reportPath = ./facter.json;

          # Set once, at first install, and never bumped afterwards -- these
          # tell NixOS/Home Manager which stateful defaults to preserve
          # across upgrades; they are not a "target version".
          system.stateVersion = "26.05";
          home-manager.users.${config.my.user}.home.stateVersion = "26.05";
          # Default (0.5, from core-options) only fits two columns even on
          # a wide monitor; three fits more comfortably here.
          home-manager.users.${config.my.user}.myConfig.niri.defaultColumnWidthProportion = 0.33;

          programs.steam.remotePlay.openFirewall = true;
        }

        (lib.mkIf config.host.bulkDisk.enable {
          disko.devices.disk.bulk = (import ./disko-bulk.nix { }).disko.devices.disk.bulk;

          # Unlocked after boot (not in the initrd, see disko-bulk.nix) and
          # nofail throughout, so a dead, unplugged or not-yet-formatted HDD
          # costs a 10s timeout instead of an emergency shell.
          environment.etc.crypttab.text = ''
            cryptbulk /dev/disk/by-partlabel/thomas-desktop-bulk - tpm2-device=auto,nofail,x-systemd.device-timeout=10s
          '';
          fileSystems."/mnt/hdd".options = [
            "nofail"
            "x-systemd.device-timeout=10s"
          ];
        })
      ];
    };
}
