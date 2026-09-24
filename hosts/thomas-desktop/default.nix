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
        nixos.gaming-steam
        nixos.gaming-minecraft
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
          # Two columns (the shared 0.5 default from core-options) is
          # deliberate here: with Mod+Comma to stack a window into the
          # current column (2 per column), that's a 2x2 grid feel of up
          # to 4 windows, not 3 skinny columns.

          # niri auto-sorts outputs by connector name (DP-1 before
          # HDMI-A-1), which put the U2414H on the right even though it
          # sits on the left. Pin both positions to the physical layout;
          # positions are in logical pixels (scale 1, so 1920x1080).
          home-manager.users.${config.my.user} = {
            home.stateVersion = "26.05";
            myConfig.niri.extraOutput = ''
              output "HDMI-A-1" {
                  position x=0 y=0
              }
              output "DP-1" {
                  position x=1920 y=0
              }
            '';
          };

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
