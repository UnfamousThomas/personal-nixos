{ inputs, ... }:
{
  flake.modules.nixos.security-agenix =
    { pkgs, ... }:
    {
      imports = [ inputs.agenix.nixosModules.default ];

      # The age key, put here by the installers: normally the one shared
      # key (README "Secrets"), so every host can decrypt every secret.
      age.identityPaths = [ "/var/lib/agenix/host.key" ];

      environment.systemPackages = [
        inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.age # age-keygen, for the per-user key (README "Secrets")
      ];
    };
}
