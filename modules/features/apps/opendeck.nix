{
  # OpenDeck (open-source Stream Deck software, supports the original
  # Elgato plugins) isn't packaged in nixpkgs -- installed via Flathub
  # instead, through the flatpak module's declared-apps list (flatpak.nix).
  #
  # OpenDeck's own install docs call for udev rules granting the logged-in
  # user access to the Stream Deck's USB/hidraw device (root-only by
  # default). Matched by vendor ID alone rather than copying upstream's
  # per-model product-ID list, so a future Stream Deck model is picked up
  # without editing this file again.
  flake.modules.nixos.opendeck = {
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
    '';

    myConfig.flatpak.extraApps = [ "me.amankhanna.opendeck" ];
  };
}
