{
  # `nix run github:UnfamousThomas/personal-nixos#install`
  perSystem =
    { pkgs, ... }:
    {
      apps.install = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "personal-nixos-install" (builtins.readFile ../../install/install.sh)
        );
      };
    };
}
