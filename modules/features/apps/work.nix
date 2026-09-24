{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # Work apps. Slack is a plain nixpkgs package. Granola has no Linux
  # build: `granola-install <dmg>` repackages the macOS release (see
  # pkgs/granola-install.sh, adapted from tirtha4/Granola-for-Linux) into
  # ~/Applications/granola using a downloaded stock Electron -- which is a
  # generic-Linux binary, hence nix-ld so it can run on NixOS at all.
  # Untested end to end: needs the .dmg from granola.ai downloaded by hand,
  # and the nix-ld library list below is a best guess for Electron.
  flake.modules.nixos.work =
    { config, pkgs, ... }:
    {
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          glib
          nss
          nspr
          at-spi2-core
          cups
          dbus
          libdrm
          gtk3
          pango
          cairo
          libgbm
          expat
          libxkbcommon
          alsa-lib
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libGL
          libpulseaudio
          systemd
          fontconfig
          freetype
          libnotify
        ];
      };
      home-manager.users.${config.my.user}.imports = [ homeManager.work ];
    };

  flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.slack
        (pkgs.writeShellApplication {
          name = "granola-install";
          runtimeInputs = with pkgs; [
            nodejs
            python3
            curl
            gnumake
            gcc
            gnutar
            xz
            unzip
            coreutils
            gnugrep
            findutils
            gnused
            xdg-utils
            desktop-file-utils
          ];
          # Upstream script isn't shellcheck-clean; it's not ours to lint.
          checkPhase = "";
          text = builtins.readFile ../../../pkgs/granola-install.sh;
        })
      ];
    };
}
