{
  perSystem =
    { pkgs, inputs', ... }:
    {
      # The overlay's custom packages, buildable on their own
      # (`nix build .#sony-device-center`), plus the locked disko for
      # README "Adding the bulk disk later".
      packages = {
        inherit (pkgs) sony-device-center gradient-wallpaper pi-coding-agent;
        inherit (pkgs.piExtensions)
          pi-mcp-adapter
          pi-subagents
          pi-lsp
          pi-acp
          ;
        inherit (inputs'.disko.packages) disko;
      };

      # Built by `nix flake check` (and CI). CI also builds both host
      # toplevels (.github/workflows/check.yml).
      checks = {
        inherit (pkgs) sony-device-center gradient-wallpaper;
        install-shellcheck = pkgs.runCommand "install-shellcheck" { } ''
          ${pkgs.shellcheck}/bin/shellcheck ${../../install/install.sh} ${../../install/remote-install.sh} ${../../install/secrets-init.sh} ${../../install/build-iso.sh}
          touch $out
        '';
      };
    };
}
