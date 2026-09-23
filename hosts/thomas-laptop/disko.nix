{
  # Hardcoded rather than left as a placeholder overridden via
  # `disko-install --disk main <device>`, so `nixos-anywhere` (which has no
  # per-role disk-override flag) can install straight from this flake ref
  # with no local edits. Only ever the one NVMe drive on this laptop.
  # Partition labels carry the host name so another machine's disk plugged
  # in can never claim the same /dev/disk/by-partlabel/ path.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
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
