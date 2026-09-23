{
  # Suspend on lid close, then hibernate to the RAM-sized swap partition
  # (hosts/thomas-laptop/disko.nix) so an overnight suspend can't drain the
  # battery. Verify hibernate resumes cleanly first (README "First boot").
  flake.modules.nixos.laptop-power = {
    services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
    systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";
  };
}
