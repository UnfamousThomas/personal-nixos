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
          "colors"
          "break"
        ];
      };
    };
  };
}
