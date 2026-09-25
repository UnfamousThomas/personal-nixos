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

      # Falloria's internal CA, so system tools (curl, git, etc.) trust
      # internally-issued certs for internal services without per-app
      # workarounds. Rotate this file if platform/infra ever reissues the
      # root CA (see infra repo's root_ca.crt).
      security.pki.certificateFiles = [ ../../../assets/falloria-internal-ca.crt ];
    };

  flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.slack
        pkgs.granola
        pkgs.claude-code
      ];
    };
}
