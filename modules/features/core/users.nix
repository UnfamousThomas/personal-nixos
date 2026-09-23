{
  flake.modules.nixos.core-users = {
    programs.zsh.enable = true; # registers zsh in /etc/shells; rc-file config lives in Home Manager

    users.users.thomas = {
      isNormalUser = true;
      description = "Thomas";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
      ];
      shell = "/run/current-system/sw/bin/zsh";
    };
  };
}
