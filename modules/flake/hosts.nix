{
  inputs,
  config,
  lib,
  ...
}:
let
  # Every directory under hosts/ is a host. Each one's default.nix is a
  # flake-parts module defining flake.modules.nixos.<directory name>.
  # Hosts live outside ./modules so import-tree never picks up their
  # disko.nix as a flake-parts module.
  hostNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../hosts)
  );
in
{
  imports = map (name: ../../hosts + "/${name}") hostNames;

  flake.nixosConfigurations = lib.genAttrs hostNames (
    name:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        config.flake.modules.nixos.${name}
        { networking.hostName = name; }
      ];
    }
  );
}
