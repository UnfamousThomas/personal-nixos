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
  flake.modules.homeManager.hidden-apps =
    { lib, ... }:
    {
      xdg.desktopEntries = lib.genAttrs [ "qt5ct" "qt6ct" "nixos-manual" ] (name: {
        name = name;
        type = "Application";
        noDisplay = true;
      });
    };
}
