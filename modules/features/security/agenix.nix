{ inputs, ... }:
{
  flake.modules.nixos.security-agenix =
    { pkgs, ... }:
    {
      imports = [ inputs.agenix.nixosModules.default ];
      environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.default ];
    };
}
