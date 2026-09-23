{
  # `nix flake init -t github:UnfamousThomas/personal-nixos#devenv-project`
  flake.templates.devenv-project = {
    path = ../../templates/devenv-project;
    description = "devenv + direnv project scaffold (devenv.nix, devenv.yaml, .envrc)";
  };
}
