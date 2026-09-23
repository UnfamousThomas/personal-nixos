{
  flake.modules.homeManager.minecraft =
    { pkgs, ... }:
    {
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
