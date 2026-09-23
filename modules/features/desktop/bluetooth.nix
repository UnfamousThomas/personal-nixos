{
  # hardware.bluetooth.enable itself comes from Noctalia's
  # recommendedServices (desktop-noctalia); this adds a full pairing/trust
  # GUI+tray, since Noctalia's own widget is quick-toggle only.
  flake.modules.nixos.desktop-bluetooth = {
    services.blueman.enable = true;
  };
}
