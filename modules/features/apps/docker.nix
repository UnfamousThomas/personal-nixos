{
  # Standard (rootful) Docker + membership in the `docker` group, over
  # rootless mode: this is a single-user personal machine (not a shared
  # multi-tenant box), and rootful Docker has fewer compatibility surprises
  # with devcontainers, docker-compose bind mounts and Steam/Proton-adjacent
  # tooling than rootless mode's network/volume quirks.
  flake.modules.nixos.docker = {
    virtualisation.docker.enable = true;
    users.users.thomas.extraGroups = [ "docker" ];
  };
}
