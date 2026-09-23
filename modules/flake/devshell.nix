{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # `nix develop` in the repo root: tools for maintaining this flake
      # itself (not per-project tooling -- that's devenv, see
      # features/apps/devenv.nix and templates/devenv-project).
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.nixfmt-rfc-style
          pkgs.statix
          pkgs.deadnix
          pkgs.nix-update
          inputs.agenix.packages.${system}.default
          inputs.disko.packages.${system}.disko
        ];
      };
    };
}
