{
  # Apps that install with a launcher entry nobody asked for and nobody
  # needs -- a bare NoDisplay override in ~/.local/share/applications
  # shadows the system-wide one (same filename, user data dir wins per
  # the XDG spec), without touching the package itself.
  #
  # - qt5ct/qt6ct: manual Qt theming, redundant since Stylix themes Qt
  #   automatically already.
  # - nixos-manual: the browsable NixOS manual, not something reached for
  #   day to day.
  # - kvantummanager: manual Kvantum theming, same story as qt5ct/qt6ct.
  # - btop: the desktop entry duplicates the `top`/`btop` terminal alias;
  #   it's a TUI, not something to launch from an app grid.
  # - blueman-manager: Bluetooth Manager -- redundant now that Noctalia's
  #   own control center has Bluetooth built in.
  # - dev.noctalia.Noctalia: the shell's own entry for itself. It's
  #   already running as the desktop shell; "launching" it from its own
  #   search isn't a useful action.
  flake.modules.homeManager.hidden-apps =
    { lib, ... }:
    {
      xdg.desktopEntries = lib.genAttrs [
        "qt5ct"
        "qt6ct"
        "nixos-manual"
        "kvantummanager"
        "btop"
        "blueman-manager"
        "dev.noctalia.Noctalia"
      ] (name: {
        name = name;
        type = "Application";
        noDisplay = true;
      });
    };
}
