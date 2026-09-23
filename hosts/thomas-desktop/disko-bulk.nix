# 1TB HDD: bulk storage (Steam library overflow, media, backups).
#
# Kept separate from ./disko.nix so it can be formatted on its own with the
# disko CLI (README "Adding the bulk disk later") without touching the SSD.
# default.nix imports it when host.bulkDisk.enable is set; `device` is then
# overridden by `disko-install --disk bulk <device>` at install time.
{
  device ? "/dev/disk/by-id/CHANGE_ME_HDD",
  ...
}:
{
  disko.devices.disk.bulk = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions.storage = {
        label = "thomas-desktop-bulk";
        size = "100%";
        content = {
          type = "luks";
          name = "cryptbulk";
          # Unlocked in stage 2 via /etc/crypttab (default.nix) instead, so
          # the HDD can never block the initrd.
          initrdUnlock = false;
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
}
