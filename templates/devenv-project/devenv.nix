{ pkgs, ... }:
{
  # https://devenv.sh/basics/
  packages = [ pkgs.git ];

  # Pick what this project needs -- toolchains live here, per-project, not
  # in the machine-wide config.
  # languages.go.enable = true;
  # languages.typescript.enable = true;
  # languages.java.enable = true;
  # languages.javascript = { enable = true; npm.enable = true; };

  enterShell = ''
    echo "devenv ready: $(basename "$PWD")"
  '';
}
