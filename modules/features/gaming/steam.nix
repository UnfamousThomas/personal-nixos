{
  flake.modules.nixos.steam =
    { lib, pkgs, ... }:
    {
      hardware.graphics.enable32Bit = true;

      programs.steam = {
        enable = true;
        # Opens the Remote Play ports on every interface. Off by default so a
        # laptop on public Wi-Fi exposes nothing; hosts that stream at home
        # turn it on (see hosts/thomas-desktop).
        remotePlay.openFirewall = lib.mkDefault false;
        gamescopeSession.enable = true; # also enables programs.gamescope
        extraCompatPackages = [ pkgs.proton-ge-bin ];
      };

      programs.gamemode.enable = true;
    };

  flake.modules.homeManager.mangohud = {
    # No NixOS-level MangoHud module exists; this is genuinely HM-only.
    programs.mangohud = {
      enable = true;
      settings = {
        fps_limit = 0;
        gpu_stats = true;
        cpu_stats = true;
        frametime = true;
        no_display = false;
      };
    };
  };
}
