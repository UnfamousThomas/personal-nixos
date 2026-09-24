{
  flake.modules.homeManager.shell = {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history.size = 10000;
      # End/Right-arrow already accept an autosuggestion by default; Tab
      # doesn't (it's bound to normal completion). Make Tab do either,
      # depending on whether a suggestion is currently showing.
      initContent = ''
        _accept_autosuggest_or_complete() {
          if [[ -n "$POSTDISPLAY" ]]; then
            zle autosuggest-accept
          else
            zle expand-or-complete
          fi
        }
        zle -N _accept_autosuggest_or_complete
        bindkey '^I' _accept_autosuggest_or_complete

        # Ctrl+Left/Right jump by word. Terminals send ESC [ 1 ; 5 D/C,
        # which zsh doesn't bind by default.
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word
      '';
      # Fastfetch draws its banner only for interactive shells (initExtra
      # never runs for non-interactive ones), i.e. each new terminal/tab.
      initExtra = ''
        fastfetch
      '';
      shellAliases = {
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
