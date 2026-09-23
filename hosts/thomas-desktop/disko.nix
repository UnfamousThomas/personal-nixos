{
  hasBulkDisk ? true,
  lib,
  ...
}:
{
  disko.devices.disk = {
    # 500G SSD: OS, sized to fit comfortably. `device` is a placeholder --
    # overridden via `disko-install --disk main <device>`.
    main = {
      type = "disk";
      device = "/dev/disk/by-id/CHANGE_ME_SSD";
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
  } // lib.optionalAttrs hasBulkDisk {
    # 1TB HDD: bulk storage (Steam library overflow, media, backups) --
    # overridden via `disko-install --disk bulk <device>`. Omitted entirely
    # when hasBulkDisk = false (see default.nix) so nothing tries to format
    # or mount a disk that isn't connected yet.
    bulk = {
      type = "disk";
      device = "/dev/disk/by-id/CHANGE_ME_HDD";
      content = {
        type = "gpt";
        partitions.storage = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptbulk";
            settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes."@" = {
                mountpoint = "/mnt/hdd";
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
}
