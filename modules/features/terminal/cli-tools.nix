{
  flake.modules.homeManager.cli-tools = {
    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
    };
    programs.bat.enable = true;
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.ripgrep.enable = true;
    programs.fd.enable = true;
    programs.btop.enable = true;
  };
}
