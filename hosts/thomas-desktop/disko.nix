{
  # 500G SSD: OS. The bulk HDD is in ./disko-bulk.nix. `device` is a
  # placeholder -- overridden via `disko-install --disk main <device>`.
  # Partition labels carry the host name so another machine's disk plugged
  # in (e.g. the laptop SSD over USB) can never claim the same
  # /dev/disk/by-partlabel/ path as this host's root or ESP.
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/disk/by-id/CHANGE_ME_SSD";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            label = "thomas-desktop-ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            label = "thomas-desktop-root";
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
  };
}
