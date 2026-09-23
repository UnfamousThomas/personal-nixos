{
  flake.modules.homeManager.minecraft =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lunar-client
        prismlauncher
        temurin-bin-8 # 1.8 - 1.16
        temurin-bin-17 # 1.17 - 1.20.4
        temurin-bin-21 # 1.20.5+
      ];
    };
}
