{ config, inputs, ... }:
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

      # The deployments repo's own shared charts/internal-ca -- the one CA
      # every self-signed cert in the infra cluster chains to (gateway
      # listener and backend certs, openbao-access's own cert), so system
      # tools (curl, git, etc.) trust those without per-app workarounds.
      # Needed because step-ca -- the fleet's real org-wide root, which
      # this file used to point at -- has a broken ACME path right now
      # (ca.falloria.dev doesn't resolve from inside the infra cluster)
      # and nothing in the cluster actually issues off it; confirmed
      # nothing else in this repo or fleet-infra/deployments depends on
      # that real root, so it was dropped rather than kept alongside an
      # unused one. Re-export and replace if this CA ever rotates
      # (kubectl -n cert-manager get secret internal-ca -o
      # jsonpath='{.data.tls\.crt}' | base64 -d) -- one shared file, not
      # a separate one per workload (this used to be openbao-gateway-ca.crt,
      # a dedicated CA for just openbao.infra.falloria.dev's own listener,
      # before that per-workload sprawl was consolidated).
      security.pki.certificateFiles = [ ../../../assets/falloria-internal-ca.crt ];

      # Flox sends usage metrics by default; this is its documented
      # system-wide switch (flox-config(1)).
      environment.etc."flox.toml".text = ''
        disable_metrics = true
      '';
    };

  flake.modules.homeManager.work =
    { lib, pkgs, ... }:
    {
      # devbase's team global tools (Flox `global` environment: Claude Code,
      # jq, ...) in every zsh. Published with devbase's environments/global.toml.
      # Runs last, so anything earlier in .zshrc is already set up.
      programs.zsh.initContent = lib.mkAfter ''
        eval "$(flox activate -r thomas-palts/global -m run)"
      '';

      home.packages = [
        pkgs.slack
        pkgs.granola
        # Flox isn't in nixpkgs: from its own flake (input in flake.nix, cache in
        # core/nix-settings.nix).
        inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
