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

      # Falloria's internal CA, so system tools (curl, git, etc.) trust
      # internally-issued certs for internal services without per-app
      # workarounds. Rotate this file if platform/infra ever reissues the
      # root CA (see infra repo's root_ca.crt).
      #
      # falloria-internal-fallback-ca.crt: a separate, narrower CA -- the
      # deployments repo's own shared charts/internal-ca, one CA every
      # self-signed cert in that cluster now chains to (gateway listener
      # and backend certs, openbao-access's own cert), not Falloria's own
      # org-wide root. Needed because step-ca's own ACME path is broken
      # right now (ca.falloria.dev doesn't resolve from inside the infra
      # cluster -- unrelated infrastructure, not fixed by this file).
      # Re-export and replace if this CA ever rotates (kubectl -n
      # cert-manager get secret internal-ca -o jsonpath='{.data.tls\.crt}'
      # | base64 -d) -- one shared file now, not a separate one per
      # workload (this used to be openbao-gateway-ca.crt, a dedicated CA
      # for just openbao.infra.falloria.dev's own listener, before that
      # per-workload sprawl was consolidated).
      security.pki.certificateFiles = [
        ../../../assets/falloria-internal-ca.crt
        ../../../assets/falloria-internal-fallback-ca.crt
      ];

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
