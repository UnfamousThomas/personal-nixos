{
  # Desktop has no touchpad, so this stays out of the shared niri.nix base
  # and gets appended only for the laptop, via the extraInput hook.
  flake.modules.homeManager.laptop-touchpad = {
    myConfig.niri.extraInput = ''
      touchpad {
          tap
          natural-scroll
          dwt
      }
    '';
  };
}
