{
  # Plain nixpkgs package rather than the cachix/devenv flake input: that
  # flake pulls in cachix's own Haskell-based tooling transitively, which
  # is a much heavier, IFD-heavy dependency chain for what's just "install
  # the devenv CLI." nixpkgs' devenv is what actually runs devenv.nix /
  # devenv.yaml in a project -- it doesn't need to be built *from* the
  # devenv flake to do that.
  flake.modules.homeManager.devenv =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.devenv ];
      programs.direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
    };
}
