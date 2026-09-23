{ swapSizeGiB, ... }:
{
  # `device` is a placeholder -- always overridden at install time via
  # `disko-install --disk main <device>` (see install/install.sh). Never
  # hardcode a real device path here.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/CHANGE_ME";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        # Sized to this host's actual detected RAM (hosts/thomas-laptop/facter.json)
        # so it can hold a full hibernation image. NOTE: disko's own
        # lib/types/swap.nix flags encrypted-swap + hibernate-resume as not
        # fully supported (resumeDevice below only sets boot.resumeDevice;
        # the kernel `resume=` parameter is set by hand in ./default.nix).
        # Treat hibernate as "try it after install, fall back to suspend if
        # it doesn't wake cleanly" rather than a guaranteed feature.
        swap = {
          size = "${toString swapSizeGiB}G";
          content = {
            type = "luks";
            name = "cryptswap";
            settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
        };

        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
