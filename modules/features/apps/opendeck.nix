{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
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
  flake.modules.nixos.opendeck =
    { config, ... }:
    {
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
      '';

      myConfig.flatpak.extraApps = [ "me.amankhanna.opendeck" ];
      home-manager.users.${config.my.user}.imports = [ homeManager.opendeck ];
    };

  # Starts hidden (no window, tray icon only -- see main.rs's `--hide` arg)
  # so the hardware keeps working without a window cluttering the desktop.
  # Its own Settings > "background" is also on, so closing the window by
  # hand afterwards hides it again rather than quitting the backend.
  flake.modules.homeManager.opendeck = {
    myConfig.niri.extraAutostart = ''
      spawn-at-startup "flatpak" "run" "me.amankhanna.opendeck" "--hide"
    '';
  };
}
