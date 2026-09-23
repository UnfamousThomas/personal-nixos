{
  flake.modules.homeManager.discord =
    { pkgs, ... }:
    {
      # Stock Discord over Vesktop, by request -- note the tradeoff: Vesktop
      # (an Electron rebuild with Vencord baked in and better Wayland
      # screenshare support) is what actually made screen sharing under
      # niri reliable. Stock Discord's own Electron/WebRTC screen capture
      # on Wayland is known to be flakier; if that turns out to matter,
      # worth revisiting.
      home.packages = [ pkgs.discord ];
    };
}
