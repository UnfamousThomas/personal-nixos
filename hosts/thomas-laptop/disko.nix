{
  # `device` is a placeholder -- always overridden at install time via
  # `disko-install --disk main <device>` (see install/install.sh). Never
  # hardcode a real device path here. Partition labels carry the host name
  # so another machine's disk plugged in can never claim the same
  # /dev/disk/by-partlabel/ path as this host's root, swap or ESP.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/CHANGE_ME";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          label = "thomas-laptop-ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        # Sized to this laptop's RAM so it can hold a full hibernation
        # image -- change it if the RAM isn't 8 GiB. NOTE: disko's own
        # lib/types/swap.nix flags encrypted-swap + hibernate-resume as not
        # fully supported (resumeDevice below only sets boot.resumeDevice;
        # the kernel `resume=` parameter is set by hand in ./default.nix).
        # Treat hibernate as "try it after install, fall back to suspend if
        # it doesn't wake cleanly" rather than a guaranteed feature.
        swap = {
          label = "thomas-laptop-swap";
          size = "8G";
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
          label = "thomas-laptop-root";
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
