{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  fontconfig,
  freetype,
  alsa-lib,
  libx11,
  libxext,
  libxi,
  libxrender,
  libxtst,
}:
# JetBrains' standalone Kotlin language server (github.com/Kotlin/kotlin-lsp,
# alpha). Not in nixpkgs. The Linux VS Code extension (.vsix, just a zip) is
# the one artifact that ships the whole server together with the JetBrains
# Runtime it needs (`jbr/`), so this repackages that and patches the ELF
# files for NixOS rather than pointing it at a system JDK.
# Update: take the version from the release page's vsix links, e.g.
#   nix store prefetch-file https://download.jetbrains.com/language-server/kotlin-server/<version>/kotlin-server-<ext version>-linux-amd64.vsix
stdenv.mkDerivation rec {
  pname = "kotlin-lsp";
  version = "263.4702.0";
  extVersion = "0.0.12";

  src = fetchurl {
    url = "https://download.jetbrains.com/language-server/kotlin-server/${version}/kotlin-server-${extVersion}-linux-amd64.vsix";
    hash = "sha256-5H5dc/iQrXKqulmKVStKT6zsP3NiapOA7t0a2evyfBA=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
  ];

  # Native libraries of the bundled JBR and helper libs (rocksdb, pty4j, ...).
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    fontconfig
    freetype
    alsa-lib
    libx11
    libxext
    libxi
    libxrender
    libxtst
  ];

  # The JBR's AWT/audio/etc. libraries reference libraries a headless
  # language server never loads.
  autoPatchelfIgnoreMissingDeps = true;

  # A .vsix has no top-level directory to cd into.
  sourceRoot = ".";
  unpackCmd = "unzip -q $curSrc";

  dontConfigure = true;
  dontBuild = true;
  # Nothing here is worth stripping, and it's over a gigabyte.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share $out/bin
    cp -r extension/server $out/share/kotlin-lsp
    # The launcher script is deprecated upstream in favour of bin/intellij-server.
    makeWrapper $out/share/kotlin-lsp/bin/intellij-server $out/bin/kotlin-lsp
    runHook postInstall
  '';

  meta = {
    description = "Kotlin language server by JetBrains (standalone, no IntelliJ needed)";
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "kotlin-lsp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
