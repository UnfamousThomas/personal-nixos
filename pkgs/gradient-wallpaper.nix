{
  lib,
  stdenvNoCC,
  imagemagick,
}:
stdenvNoCC.mkDerivation {
  pname = "gradient-wallpaper";
  version = "1.0.0";

  nativeBuildInputs = [ imagemagick ];
  dontUnpack = true;

  # Catppuccin Mocha base -> accent gradients, rendered reproducibly at
  # build time instead of checking binary images into the repo.
  # gradient-mocha.png is the default (Stylix points at it) and matches the
  # muted green accent; the rest exist so Noctalia's wallpaper picker,
  # which browses a directory, has something to show.
  buildPhase = ''
    runHook preBuild
    render() { magick -size 3840x2160 gradient:'#1e1e2e'-"$2" "$1.png"; }
    render gradient-mocha '#4f6b4d'   # default: muted green
    render gradient-mauve '#6e5a8a'
    render gradient-blue  '#4a6a9c'
    render gradient-teal  '#3f7a72'
    render gradient-peach '#94613f'
    render gradient-rose  '#8a5a68'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/wallpapers
    cp gradient-*.png $out/share/wallpapers/
    runHook postInstall
  '';

  meta = {
    description = "Catppuccin Mocha base-to-accent gradient wallpapers, rendered at build time";
    platforms = lib.platforms.all;
  };
}
