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
          # Power button (short press) suspends the box. niri's own power-key
          # handling is disabled in the niri config above so logind owns the
          # key; this keeps one code path instead of niri's, which doesn't
          # fire reliably here.
          services.logind.settings.Login.HandlePowerKey = "suspend";
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
            # niri takes over the power key by default (its own suspend is
            # flaky). Hand it back to logind, which we've pointed at suspend
            # (HandlePowerKey below), for one well-tested path.
            myConfig.niri.extraInput = ''
              disable-power-key-handling
            '';
            myConfig.niri.extraOutput = ''
              output "HDMI-A-1" {
                  position x=0 y=0
              }
              output "DP-1" {
                  position x=1920 y=0
              }
            '';
            # Sidebar entry in Nautilus (Mod+E) pointing straight at the
            # user-writable Bulk dir created by the hdd-bulk-dir service
            # below. Nautilus reads the GNOME GTK3 bookmarks file.
            xdg.configFile."gtk-3.0/bookmarks".text = ''
              file:///mnt/hdd/Bulk Bulk Storage
            '';
          };

          programs.steam.remotePlay.openFirewall = true;

          # GTX 1060 (Pascal) was on the nouveau driver, which has no
          # hardware video decode -- Firefox (and GPU work generally) fell
          # back to software rendering, hence the lag on videos and even on
          # simple page loads. Switch to NVIDIA's proprietary driver, which
          # supports Pascal and enables real WebRender/video-decode accel.
          #
          # Safe to switch: the running session keeps nouveau until the next
          # reboot (the module only blacklists nouveau going forward), and
          # systemd-boot keeps the previous generations (configurationLimit
          # = 5) selectable at boot as a rollback if the driver ever fails.
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia = {
            # modesetting.enable (required for Wayland/niri) is on by
            # default. NVIDIA's open kernel modules only support Turing and
            # newer, so Pascal must stay on the closed ones.
            open = false;
            # The mainstream driver dropped Pascal (GTX 10-series) as of the
            # 595.x branch -- the 595.99.02 driver refuses to bind the GTX
            # 1060 ("supported through the NVIDIA 580.xx Legacy drivers"),
            # leaving the box without a working GPU (nouveau blacklisted).
            # Pin the 580 legacy branch, which still supports Pascal.
            package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          };

          # niri wiki (Nvidia page): the driver doesn't return freed buffers
          # to its pool, so niri's VRAM usage creeps toward ~1GiB instead of
          # ~100MiB. Declarative version of the per-process app-profile fix.
          environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors".text =
            builtins.toJSON {
              rules = [
                {
                  pattern = {
                    feature = "procname";
                    matches = "niri";
                  };
                  profile = "Limit Free Buffer Pool On Wayland Compositors";
                }
              ];
              profiles = [
                {
                  name = "Limit Free Buffer Pool On Wayland Compositors";
                  settings = [
                    {
                      key = "GLVidHeapReuseRatio";
                      value = 0;
                    }
                  ];
                }
              ];
            };
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

          # The btrfs root of the HDD is owned by root, so write access has
          # to come from a chown'd directory. Disko sets up the filesystem
          # once, not per boot, so create it here -- after local-fs.target so
          # it never races the (nofail) mount, and silently skipped when the
          # HDD is absent. The Nautilus bookmark above points at this dir.
          systemd.services.hdd-bulk-dir = {
            description = "Create the user-writable Bulk directory on the HDD";
            # Order after the mount unit itself (not just local-fs.target):
            # the HDD is unlocked in stage 2 via crypttab and can come up a
            # couple of seconds after local-fs.target. mountpoint is not in
            # the service's PATH, so read /proc/mounts with grep instead.
            after = [ "local-fs.target" "mnt-hdd.mount" ];
            wants = [ "local-fs.target" "mnt-hdd.mount" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              if grep -q ' /mnt/hdd ' /proc/mounts; then
                install -d -o thomaspalts -g users -m 0755 /mnt/hdd/Bulk
              fi
            '';
          };
        })
      ];
    };
}
