{
  perSystem =
    { pkgs, inputs', ... }:
    {
      # The overlay's custom packages, buildable on their own
      # (`nix build .#sony-device-center`), plus the locked disko for
      # README "Adding the bulk disk later".
      packages = {
        inherit (pkgs) sony-device-center gradient-wallpaper;
        inherit (inputs'.disko.packages) disko;
      };

      # Built by `nix flake check` (and CI). CI also builds both host
      # toplevels (.github/workflows/check.yml).
      checks = {
        inherit (pkgs) sony-device-center gradient-wallpaper;
        install-shellcheck = pkgs.runCommand "install-shellcheck" { } ''
          ${pkgs.shellcheck}/bin/shellcheck ${../../install/install.sh}
          touch $out
        '';
      };
    };
}
