{
  flake.modules.homeManager.minecraft =
    { pkgs, ... }:
    {
      # Shadows the package's own (bare-bones) entry, same filename. The
      # package's icon sits outside the hicolor tree so a themed name never
      # resolves; use the official avatar (assets/lunarclient.png) by path.
      xdg.desktopEntries.lunarclient = {
        name = "Lunar Client";
        genericName = "Minecraft Launcher";
        comment = "Minecraft PvP client with mods, cosmetics and performance tweaks";
        exec = "lunarclient %U";
        icon = "${../../../assets/lunarclient.png}";
        mimeType = [
          "application/x-lcpack"
          "application/x-dawnpack"
          "x-scheme-handler/lunarclient"
        ];
        categories = [ "Game" ];
        terminal = false;
      };

      home.packages = [
        pkgs.lunar-client
        # Prism picks the right JDK per instance.
        (pkgs.prismlauncher.override {
          jdks = with pkgs; [
            temurin-bin-8 # 1.8 - 1.16
            temurin-bin-17 # 1.17 - 1.20.4
            temurin-bin-21 # 1.20.5+
          ];
        })
      ];
    };
}
