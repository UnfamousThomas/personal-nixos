{
  flake.modules.homeManager.shell = {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history.size = 10000;
      shellAliases = {
        ls = "eza --icons";
        ll = "eza -l --icons --git";
        la = "eza -la --icons --git";
        lt = "eza --tree --icons";
        cat = "bat";
        find = "fd";
        grep = "rg";
        top = "btop";
        gs = "git status";
        gd = "git diff";
        gc = "git commit";
        gp = "git push";
      };
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        format = "$directory$git_branch$git_status$character";
      };
    };
  };
}
