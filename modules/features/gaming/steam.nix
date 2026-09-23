{
  flake.modules.nixos.steam =
    { pkgs, ... }:
    {
      hardware.graphics.enable32Bit = true;

      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
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
