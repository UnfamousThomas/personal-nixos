{
  inputs,
  config,
  lib,
  ...
}:
{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently. The Pi packages come from their own
  # overlay (features/apps/pi.nix), which anyone consuming just the Pi setup
  # can use on its own.
  flake.overlays.default = lib.composeExtensions config.flake.overlays.pi (
    final: _prev: {
      sony-device-center = final.callPackage ../../pkgs/sony-device-center.nix { };
      gradient-wallpaper = final.callPackage ../../pkgs/gradient-wallpaper.nix { };
      granola = final.callPackage ../../pkgs/granola.nix { };

      # The wallpaper panel's Flatten toggle, Built-in/Wallpaper/Community
      # palette-source tabs and Dark/Light/Auto switcher are hard-coded in
      # Noctalia's UI with no setting to hide them. Stylix owns the colors and
      # the theme stays dark (noctalia.nix), so they only get in the way: hide
      # them when the panel opens. Hidden rather than removed, because other
      # panel code still reads the widgets. Building this compiles Noctalia
      # locally, since the upstream binary cache doesn't have the patched build.
      noctalia =
        inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/shell/wallpaper/panel/wallpaper_panel.cpp \
                --replace-fail 'void WallpaperPanel::onOpen(std::string_view /*context*/) {' \
                'void WallpaperPanel::onOpen(std::string_view /*context*/) {
                if (m_flattenLabel != nullptr) { m_flattenLabel->setVisible(false); }
                if (m_flattenToggle != nullptr) { m_flattenToggle->setVisible(false); }
                if (m_favoritePaletteSourceSegmented != nullptr) { m_favoritePaletteSourceSegmented->setVisible(false); }
                if (m_favoriteThemeSegmented != nullptr) { m_favoriteThemeSegmented->setVisible(false); }'
            '';
          });

      # Upstream's test suite includes a case that spawns a bwrap sandbox and
      # tries to configure a loopback interface inside it -- needs network
      # namespace privileges a Nix build sandbox (and GitHub Actions' runner)
      # doesn't grant, so it fails there regardless of whether the code under
      # test is actually broken. Skip tests for the packaged build; they still
      # run in upstream's own CI, which does have those privileges.
      openwave = inputs.openwave.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
        doCheck = false;
      });
    }
  );
}
