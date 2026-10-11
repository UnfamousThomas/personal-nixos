{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  # Split from Minecraft so a host can have one without the other
  # (thomas-laptop keeps Minecraft, drops Steam/Proton).
  flake.modules.nixos.gaming-steam =
    { config, ... }:
    {
      imports = [ nixos.steam ];
      home-manager.users.${config.my.user}.imports = [ homeManager.mangohud ];
    };

  flake.modules.nixos.gaming-minecraft =
    { config, pkgs, ... }:
    {
      home-manager.users.${config.my.user}.imports = with homeManager; [
        minecraft
        mangohud
      ];

      # Lunar Client self-updates by downloading a fresh, plain
      # dynamically-linked binary that bypasses the Nix wrapper -- it fails
      # with "cannot run dynamically linked executables" (exit 127) without
      # this, every launch.
      programs.nix-ld.enable = true;

      # That self-updated binary also loses the Nix wrapper's RPATH, so it
      # can't find OpenGL/X11/audio on its own either -- it fails with
      # "OpenGL is not supported: Could not retrieve OpenGL functions".
      # hardware.graphics.package is the host's actual driver (nvidia on
      # thomas-desktop), so libGL resolves to the same library the rest of
      # the system renders with.
      programs.nix-ld.libraries = with pkgs; [
        config.hardware.graphics.package
        libglvnd
        vulkan-loader
        xorg.libX11
        xorg.libXext
        xorg.libXcursor
        xorg.libXi
        xorg.libXrandr
        xorg.libXrender
        xorg.libXtst
        xorg.libXxf86vm
        xorg.libXinerama
        libpulseaudio
        alsa-lib
      ];
    };
}
