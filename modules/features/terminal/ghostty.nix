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
      };
    };
  };
}
