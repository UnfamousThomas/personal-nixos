{
  # KVM/QEMU via libvirt + virt-manager, for a Windows VM (WSL2 testing).
  # Toggle it by commenting out `windows-vm` in modules/roles/workstation.nix.
  #
  # WSL2 runs on Hyper-V inside the guest, so it needs nested virtualization:
  # kvm_intel's `nested` param is already Y on this kernel, and the VM's CPU
  # must be set to `host-passthrough` in virt-manager (the default model hides
  # VT-x from the guest). UEFI (OVMF) images ship with QEMU; swtpm gives
  # Windows 11 its TPM 2.0.
  #
  # Guest drivers: attach /etc/virtio-win.iso as a second CD-ROM.
  #
  # Accepted trade-off: the libvirtd group can manage system VMs, which is
  # effectively root-equivalent (same reasoning as features/apps/docker.nix).
  flake.modules.nixos.windows-vm =
    { config, pkgs, ... }:
    {
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
      };
      programs.virt-manager.enable = true;
      users.users.${config.my.user}.extraGroups = [ "libvirtd" ];

      environment.etc."virtio-win.iso".source = pkgs.virtio-win.src;
    };
}
