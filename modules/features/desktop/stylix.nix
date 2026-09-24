{ inputs, ... }:
{
  flake.modules.nixos.desktop-stylix =
    { pkgs, ... }:
    {
      imports = [ inputs.stylix.nixosModules.stylix ];

      stylix.enable = true;
      stylix.polarity = "dark";
      # Catppuccin Mocha with a blue accent: base0E is the slot most base16
      # templates treat as the primary accent, so it holds Blue, and base0D
      # holds Sapphire to stay distinguishable from it in syntax highlighting.
      # Passed as an inline attrset (Stylix accepts path/YAML-string/attrset)
      # because Stylix's YAML loader parses colors through an IFD derivation
      # that can't be realized during `nix flake check`.
      stylix.base16Scheme = {
        base00 = "1e1e2e"; # Base
        base01 = "181825"; # Mantle
        base02 = "313244"; # Surface0
        base03 = "45475a"; # Surface1
        base04 = "585b70"; # Surface2
        base05 = "cdd6f4"; # Text
        base06 = "f5e0dc"; # Rosewater
        base07 = "b4befe"; # Lavender
        base08 = "f38ba8"; # Red
        base09 = "fab387"; # Peach
        base0A = "f9e2af"; # Yellow
        base0B = "a6e3a1"; # Green
        base0C = "94e2d5"; # Teal
        base0D = "74c7ec"; # Sapphire
        base0E = "89b4fa"; # Blue -- the accent
        base0F = "f2cdcd"; # Flamingo
      };

      # Stylix's Noctalia target turns this into Noctalia's
      # `wallpaper.default.path` (the base16Scheme above still wins for
      # colors; the image isn't used to generate a palette).
      stylix.image = "${pkgs.gradient-wallpaper}/share/wallpapers/gradient-mocha.png";

      # Niri has no Stylix target: its accent colors and cursor are set
      # directly in niri.nix (the cursor from the values below). Everything
      # else Stylix can reach (GTK, Qt, cursor, fontconfig, and any enabled
      # HM program it has a target for) is themed automatically via
      # `stylix.autoEnable` (on by default) -- and since Home Manager runs
      # here as a NixOS submodule, the NixOS-level Stylix module is enough;
      # no separate HM-side Stylix import is needed.
      stylix.fonts.monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      stylix.fonts.sizes = {
        terminal = 11;
        applications = 10;
      };

      stylix.cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
    };
}
