{
  flake.modules.nixos.desktop-audio = {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      # wireplumber.enable defaults to services.pipewire.enable; its bundled
      # monitor.bluez rules give Bluetooth A2DP/codec support automatically
      # once hardware.bluetooth.enable is also on.
    };
  };
}
