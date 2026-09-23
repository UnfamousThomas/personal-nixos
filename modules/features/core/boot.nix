{
  flake.modules.nixos.core-boot-encrypted = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # No kernel command line editing at the boot menu: init=/bin/sh would be
    # a root shell on the TPM-unlocked disk (README "First boot").
    boot.loader.systemd-boot.editor = false;

    # The ESP is small and nix.gc only removes generations older than 30
    # days, so bound how many kernel+initrd pairs can pile up on it.
    boot.loader.systemd-boot.configurationLimit = 10;

    # Required for `tpm2-device=auto` in crypttab to be honored -- the
    # legacy (non-systemd) initrd stage does not support TPM2-backed
    # unlocking at all.
    boot.initrd.systemd.enable = true;
  };
}
