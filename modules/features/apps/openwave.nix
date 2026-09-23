{ inputs, ... }:
{
  # OpenWave (Elgato Wave XLR control) ships its own maintained flake --
  # used directly rather than re-packaged. To update: bump the `openwave`
  # flake input (`nix flake lock --update-input openwave`).
  flake.modules.homeManager.openwave =
    { pkgs, ... }:
    {
      home.packages = [ inputs.openwave.packages.${pkgs.system}.default ];
    };
}
