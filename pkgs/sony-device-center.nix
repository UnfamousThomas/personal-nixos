{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  qt6,
  bluez,
  dbus,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sony-device-center";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "marconvcm";
    repo = "sony-device-center";
    tag = "v${finalAttrs.version}";
    # No official Nix packaging upstream (verified: no flake.nix/default.nix
    # in the repo). Placeholder hash -- fill in the real one on first build:
    #   nix build .#sony-device-center
    # and paste the hash it reports, or run `nix-update sony-device-center`
    # after bumping `version`/`tag` for future releases.
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative # QtQuickControls2 now lives inside qtdeclarative on Qt6, no separate attribute
    bluez
    dbus
  ];

  meta = {
    description = "Linux GUI for controlling Sony Bluetooth headphones (WH-1000XM series, WF series, etc.)";
    homepage = "https://github.com/marconvcm/sony-device-center";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sony-device-center";
  };
})
