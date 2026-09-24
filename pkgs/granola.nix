{
  lib,
  stdenv,
  fetchurl,
  unzip,
  python3,
  gnumake,
  nodejs,
  node-gyp,
  electron_44,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:
# Granola only ships macOS/Windows builds. This repackages the macOS release
# for Linux, following tirtha4/Granola-for-Linux: run the app's asar on a
# nixpkgs Electron of the same major version, patch the platform string, and
# rebuild the one native module for Linux.
let
  electron = electron_44;

  version = "7.580.1";

  # Granola's fork of better-sqlite3-multiple-ciphers ships its full C++
  # source in the app bundle but not binding.gyp; that comes from the npm
  # release of the same version.
  bs3Version = "12.9.0";
  bs3Npm = fetchurl {
    url = "https://registry.npmjs.org/better-sqlite3-multiple-ciphers/-/better-sqlite3-multiple-ciphers-${bs3Version}.tgz";
    hash = "sha256-rYzrLP5ofgwQZUf90oHw0gtAaIIA0E9AuxY6/R8QJgk=";
  };
in
stdenv.mkDerivation {
  pname = "granola";
  inherit version;

  src = fetchurl {
    url = "https://dr2v7l5emb758.cloudfront.net/${version}/Granola-${version}-mac-universal.zip";
    hash = "sha512-t4oBHjYhkZvpeZVAv3ALgnDg3yYwFkXWDWkRkrglBal3UQ+BQ1U2iPyBBaCbzGFdadr2TOLMFkpT1El8dPOEmA==";
  };

  nativeBuildInputs = [
    unzip
    python3
    gnumake
    nodejs
    node-gyp
    makeWrapper
    copyDesktopItems
  ];

  # Only the payload is wanted, not the macOS Electron framework.
  unpackPhase = ''
    runHook preUnpack
    unzip -q $src \
      'Granola.app/Contents/Resources/app.asar' \
      'Granola.app/Contents/Resources/app.asar.unpacked/*' \
      'Granola.app/Contents/Resources/icons/*'
    chmod -R u+w Granola.app
    runHook postUnpack
  '';

  sourceRoot = "Granola.app/Contents/Resources";

  postPatch = ''
    # api.granola.ai answers 500 to any request carrying platform=linux,
    # including the sign-in URL, so login is impossible as-is. The app maps
    # darwin->macOS and win32->Windows and passes anything else through
    # verbatim; rewrite that fallback so Linux reports Windows. Replacements
    # are padded to the same length because an .asar header records file
    # offsets (stock Electron doesn't verify asar integrity on Linux).
    python3 - app.asar <<'EOF'
    import sys, pathlib
    p = pathlib.Path(sys.argv[1]); data = p.read_bytes(); total = 0
    for pat in (b'?`Windows`:window.electron.platform', b'?`Windows`:process.platform'):
        rep = b'?`Windows`:`Windows`'.ljust(len(pat))
        total += data.count(pat)
        data = data.replace(pat, rep)
    if total == 0:
        sys.exit("no platform fallback found: Granola's bundler output changed")
    p.write_bytes(data)
    EOF
  '';

  # Granola's fork adds an updateHook() the renderer calls on startup, so a
  # stock npm build of the module won't do: build the bundled source.
  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    # Build against Electron's headers: the ABI has to match the runtime, and
    # Node's own headers ship a plain sqlite3.h that shadows the module's
    # SQLCipher one. The nixpkgs node-gyp wrapper force-sets npm_config_nodedir
    # to Node's, so run node-gyp.js directly instead of through it.
    export npm_config_nodedir=${electron.headers}
    bs3=app.asar.unpacked/node_modules/better-sqlite3-multiple-ciphers
    grep -q '"version": "${bs3Version}"' $bs3/package.json

    mkdir npm && tar xzf ${bs3Npm} -C npm
    cp npm/package/binding.gyp $bs3/
    rm -rf $bs3/build

    (cd $bs3 && node ${node-gyp}/lib/node_modules/node-gyp/bin/node-gyp.js rebuild --release -j $NIX_BUILD_CORES)

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    bs3=app.asar.unpacked/node_modules/better-sqlite3-multiple-ciphers
    # Keep just the two Linux binaries, not the object files or macOS leftovers.
    mkdir keep
    cp $bs3/build/Release/{better_sqlite3,test_extension}.node keep/
    rm -rf $bs3/build
    mkdir -p $bs3/build/Release
    cp keep/*.node $bs3/build/Release/

    mkdir -p $out/share/granola
    cp -r app.asar app.asar.unpacked $out/share/granola/
    # The launcher icon is assets/granola.png (Granola's own store icon),
    # in the icon theme tree so the desktop entry's plain "granola" resolves.
    install -Dm644 ${../assets/granola.png} $out/share/icons/hicolor/512x512/apps/granola.png

    makeWrapper ${lib.getExe electron} $out/bin/granola \
      --add-flags $out/share/granola/app.asar \
      --add-flags "--ozone-platform-hint=auto"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "granola";
      desktopName = "Granola";
      comment = "AI notepad for meetings";
      exec = "granola %U";
      icon = "granola";
      categories = [
        "Office"
        "Utility"
      ];
      startupWMClass = "granola";
      mimeTypes = [ "x-scheme-handler/granola" ];
    })
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # Encrypted database plus the fork's updateHook: without the latter the
    # renderer dies with "r.updateHook is not a function".
    export HOME=$TMPDIR
    ELECTRON_RUN_AS_NODE=1 NODE_PATH=$out/share/granola/app.asar/node_modules ${lib.getExe electron} -e "
      const Database = require('$out/share/granola/app.asar.unpacked/node_modules/better-sqlite3-multiple-ciphers/lib/index.js');
      const db = new Database('$TMPDIR/smoke.db');
      db.pragma(\"cipher='sqlcipher'\");
      db.pragma(\"key='smoketest'\");
      db.exec('CREATE TABLE t(a)');
      let fired = false;
      db.updateHook(() => { fired = true; });
      db.prepare('INSERT INTO t VALUES (1)').run();
      if (db.prepare('SELECT count(*) c FROM t').get().c !== 1) throw new Error('insert failed');
      if (!fired) throw new Error('updateHook did not fire');
      db.close();
    "

    runHook postInstallCheck
  '';

  meta = {
    description = "AI notepad for meetings (macOS release repackaged for Linux)";
    homepage = "https://www.granola.ai";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "granola";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
