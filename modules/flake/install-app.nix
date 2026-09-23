{ self, lib, ... }:
{
  # `nix run github:UnfamousThomas/personal-nixos#install`
  #
  # Everything the installer runs as root comes from this flake's lock file
  # (disko-install, nixos-facter), and it installs exactly the source tree
  # the app was built from.
  perSystem =
    { pkgs, inputs', ... }:
    let
      inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
    in
    {
      apps.install = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "personal-nixos-install" ''
            # the installer ISO's minimal environment doesn't ship these
            export PATH=${
              lib.makeBinPath [
                pkgs.git
                pkgs.age
                pkgs.mkpasswd
              ]
            }:$PATH
            export REPO_SRC=${self}
            export REPO_REV=${self.rev or ""}
            export DISKO_INSTALL=${inputs'.disko.packages.disko-install}/bin/disko-install
            export NIXOS_FACTER=${inputs'.nixos-facter.packages.nixos-facter}/bin/nixos-facter
            export EXTRA_SUBSTITUTERS=${lib.escapeShellArg (toString extra-substituters)}
            export EXTRA_TRUSTED_PUBLIC_KEYS=${lib.escapeShellArg (toString extra-trusted-public-keys)}
            ${builtins.readFile ../../install/install.sh}
          ''
        );
      };
    };
}
