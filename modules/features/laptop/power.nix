{
  # power-profiles-daemon is already enabled via Noctalia's
  # recommendedServices (desktop-noctalia), which is what its bar's battery
  # widget expects. upower gives it (and any other consumer) battery state.
  flake.modules.nixos.laptop-power = {
    services.upower.enable = true;
  };
}
