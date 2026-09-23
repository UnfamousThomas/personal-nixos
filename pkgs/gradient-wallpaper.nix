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

  # Catppuccin Mocha base -> mauve gradient, rendered reproducibly at build
  # time instead of checking a binary image into the repo.
  buildPhase = ''
    runHook preBuild
    magick -size 3840x2160 gradient:'#1e1e2e'-'#cba6f7' wallpaper.png
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/wallpapers
    cp wallpaper.png $out/share/wallpapers/gradient-mocha.png
    runHook postInstall
  '';

  meta = {
    description = "Catppuccin Mocha base-to-mauve gradient wallpaper, rendered at build time";
    platforms = lib.platforms.all;
  };
}
