{
  flake.modules.nixos.core-users =
    { config, ... }:
    {
      programs.zsh.enable = true; # registers zsh in /etc/shells; rc-file config lives in Home Manager

      users.users.${config.my.user} = {
        isNormalUser = true;
        # Pinned so install/install.sh can hand the copied repo checkout to
        # this user before the account exists.
        uid = 1000;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "input"
        ];
        shell = "/run/current-system/sw/bin/zsh";
        # Written by install/install.sh from a password typed at install
        # time, so no hash ever lands in this repo or the Nix store. With
        # mutable users (the default) it is only read when the account is
        # first created; change it afterwards with `passwd`.
        hashedPasswordFile = "/var/lib/user-passwords/${config.my.user}";
      };
    };
}
