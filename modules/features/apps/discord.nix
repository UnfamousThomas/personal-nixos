{
  flake.modules.homeManager.discord =
    { pkgs, ... }:
    {
      # Vesktop: Vencord baked in, plus better Wayland screenshare support
      # than stock Discord (tried stock briefly, switched back).
      home.packages = [ pkgs.vesktop ];
    };
}
