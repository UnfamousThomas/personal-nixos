{
  flake.modules.homeManager.minecraft =
    { pkgs, ... }:
    {
      # Overrides the package's own launcher entry (same filename). The icon
      # is given by path (assets/lunarclient.png): the package installs its
      # own outside the icon theme tree, so a themed name doesn't resolve.
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
