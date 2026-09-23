{
  flake.modules.homeManager.ghostty = {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        theme = "catppuccin-mocha";
        font-family = "JetBrainsMono Nerd Font Mono";
        font-size = 11;
        window-padding-x = 10;
        window-padding-y = 10;
        cursor-style = "block";
        mouse-hide-while-typing = true;
      };
    };
  };
}
