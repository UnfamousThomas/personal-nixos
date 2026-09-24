{
  flake.modules.homeManager.ghostty = {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;
      # Theme and fonts come from Stylix's Ghostty target (desktop/stylix.nix).
      settings = {
        window-padding-x = 10;
        window-padding-y = 10;
        cursor-style = "block";
        mouse-hide-while-typing = true;

        keybind = [
          # Ctrl+C copies when there's a selection; with nothing selected
          # ("performable" falls through) it's still the normal interrupt, so
          # a running command can be stopped the usual way.
          "performable:ctrl+c=copy_to_clipboard"
          # Always interrupts, selection or not (\x03 is the ^C byte).
          "ctrl+shift+c=text:\\x03"
          "ctrl+v=paste_from_clipboard"
        ];
      };
    };
  };
}
