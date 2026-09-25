{ inputs, ... }:
{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently.
  flake.overlays.default = final: prev: {
    sony-device-center = final.callPackage ../../pkgs/sony-device-center.nix { };
    gradient-wallpaper = final.callPackage ../../pkgs/gradient-wallpaper.nix { };
    granola = final.callPackage ../../pkgs/granola.nix { };
    piExtensions = final.callPackage ../../pkgs/pi-extensions.nix { };
    kotlin-lsp = final.callPackage ../../pkgs/kotlin-lsp.nix { };
    pi-agent = final.callPackage ../../pkgs/pi-agent.nix { };
    minecraft-mcp-server = final.callPackage ../../pkgs/minecraft-mcp-server.nix {
      src = inputs.minecraft-mcp-server;
    };

    # nixpkgs' recipe, pinned to the newest upstream release instead of
    # whatever nixpkgs has caught up to. To update, bump `version` and set the
    # three hashes to final.lib.fakeHash; the build then reports each correct
    # one in turn. Get them up front with:
    #   nix flake prefetch github:earendil-works/pi/v<version>
    #   nix store prefetch-file https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-<version>.tgz
    # (the npmDeps hash comes from the failed build.) If a new release adds
    # workspaces the recipe doesn't build, copy nixpkgs' package.nix into
    # pkgs/ and adapt buildPhase.
    pi-coding-agent = prev.pi-coding-agent.overrideAttrs (
      finalAttrs: _: {
        version = "0.87.1";

        src = final.fetchFromGitHub {
          owner = "earendil-works";
          repo = "pi";
          tag = "v${finalAttrs.version}";
          hash = "sha256-GUhlq6t+l6iiViOZ0bkV28v3ZDqcLvEwpZpYZ5JAyDk=";
        };

        # buildNpmPackage derives npmDeps from its npmDepsHash *argument*, so
        # overrideAttrs has to rebuild npmDeps itself.
        npmDeps = final.fetchNpmDeps {
          inherit (finalAttrs) src;
          name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
          hash = "sha256-JBIYoP2vvRNz1HONNvDJ1U3c+nmCJ7/VgNthRTkrkIA=";
          fetcherVersion = 1;
        };

        # Hydrated provider catalog, shipped by the pi-ai npm package of the
        # same version (see nixpkgs' recipe for why it's not in the source).
        modelData = final.fetchurl {
          url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
          hash = "sha256-NbRDLyfMJmX4a+67mvajmxJRlwiDwwRL2L5PToxzHKA=";
        };
      }
    );

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
  };
}
