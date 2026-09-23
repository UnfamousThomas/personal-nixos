{
  flake.modules.nixos.core-boot-encrypted = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Required for `tpm2-device=auto` in crypttab to be honored -- the
    # legacy (non-systemd) initrd stage does not support TPM2-backed
    # unlocking at all.
    boot.initrd.systemd.enable = true;
  };
}
