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

    # Terminal system info + logo banner. The maintained successor to
    # neofetch; shows the NixOS logo and a stat list, drawn from the
    # `fastfetch` call in shell.nix's initExtra.
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          source = "nixos";
          padding = {
            right = 1;
          };
        };
        display = {
          separator = "  ";
          # Steel blue to match niri's focus ring accent.
          color = "blue";
        };
        modules = [
          "title"
          "break"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "wm"
          "terminal"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "disk"
          {
            type = "weather";
            location = "Tallinn";
            # wttr.in format tokens; a literal "+" renders as a space.
            # %t temp, %C condition, %f feels-like, %w wind
            # (temperature unit comes from fastfetch's default metric
            # display, so no "&m" suffix is needed).
            outputFormat = "%l:+%t+%C+(feels+%f)+wind+%w";
            timeout = 5000;
          }
          "colors"
          "break"
        ];
      };
    };
  };
}
