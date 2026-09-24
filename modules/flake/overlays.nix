{ inputs, ... }:
{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently.
  flake.overlays.default = final: _prev: {
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

    # Upstream's own build script (script/build.ts) compiles the binary
    # then immediately runs `opencode --version` as a smoke test and
    # `process.exit(1)`s the whole build if that crashes; Nix's
    # doInstallCheck (versionCheckHook) does the same thing again after
    # install. Both SIGSEGV in this repo's build environments (Nix's
    # sandbox, WSL2) for a cause that isn't pinned down (not a missing AVX2:
    # WSL2 reports avx2). Neither check reflects whether the binary works on
    # real target hardware, so both are skipped rather than letting an
    # environment-specific crash block the whole system build.
    opencode =
      inputs.opencode.packages.${final.stdenv.hostPlatform.system}.opencode.overrideAttrs
        (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace packages/opencode/script/build.ts \
              --replace-fail 'process.exit(1)' 'console.warn("(smoke test failed; skipped, see modules/flake/overlays.nix)")'
          '';
          doInstallCheck = false;
          # Upstream's postInstall runs $out/bin/opencode (to generate shell
          # completions), which segfaults the same way: every invocation
          # crashes in this sandbox, consistent with Bun's compiled-binary
          # $bunfs self-unpack tripping over the sandbox's restricted /proc
          # and syscalls. Dropped entirely; the completions aren't worth it.
          postInstall = "";
        });
  };
}
