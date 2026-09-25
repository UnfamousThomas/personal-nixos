{ inputs, config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  # Every host. A role is a NixOS module that also wires its Home Manager
  # half for the host's user, so a host only lists roles.
  flake.modules.nixos.base =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        nixos.core-options
        nixos.core-hardware
        nixos.core-nix
        nixos.core-locale
        nixos.core-users
        nixos.core-boot-encrypted
        nixos.core-networking
        nixos.core-home-manager
        nixos.core-zram
        nixos.security-agenix
      ];
      home-manager.users.${config.my.user}.imports = [ homeManager.base ];
    };

  flake.modules.homeManager.base.imports = with homeManager; [
    shell
    cli-tools
    zk
    git
    gh
    ssh
    projects-dir
  ];
}
