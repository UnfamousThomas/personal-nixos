{
  # `nix run github:UnfamousThomas/personal-nixos#install`
  perSystem =
    { pkgs, ... }:
    {
      apps.install = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "personal-nixos-install" ''
            export PATH="${pkgs.git}/bin:$PATH" # the installer ISO's minimal environment doesn't ship git
            ${builtins.readFile ../../install/install.sh}
          ''
        );
      };
    };
}
