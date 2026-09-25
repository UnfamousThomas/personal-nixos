{
  # Standard (rootful) Docker + membership in the `docker` group, over
  # rootless mode: rootful Docker has fewer compatibility surprises with
  # devcontainers, docker-compose bind mounts and Steam/Proton-adjacent
  # tooling than rootless mode's network/volume quirks.
  #
  # Accepted trade-off: the docker group is root-equivalent (`docker run -v
  # /:/host ...`), so anything running as this user -- including AI agents
  # (Claude Code in Zed) and project code under devenv -- can become root without
  # the sudo password. Same for Nix trusted-users (core/nix-settings.nix).
  flake.modules.nixos.docker =
    { config, ... }:
    {
      virtualisation.docker.enable = true;
      # Docker's own iptables rules run before the NixOS firewall, so a
      # published port (`-p 5432:5432`) would otherwise be reachable from
      # the whole LAN. Publish on 0.0.0.0 explicitly when that's wanted.
      virtualisation.docker.daemon.settings.ip = "127.0.0.1";
      users.users.${config.my.user}.extraGroups = [ "docker" ];
    };
}
