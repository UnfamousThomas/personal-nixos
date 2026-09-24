{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # Work apps. Slack is a plain nixpkgs package; Granola is built from the
  # pinned macOS release (pkgs/granola.nix) since it has no Linux build.
  flake.modules.nixos.work =
    { config, ... }:
    {
      home-manager.users.${config.my.user}.imports = [ homeManager.work ];
    };

  flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.slack
        pkgs.granola
      ];
    };
}
