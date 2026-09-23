{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  qt6,
  bluez,
  dbus,
}:
stdenv.mkDerivation {
  pname = "sony-device-center";
  version = "0.1.5";

  # No official Nix packaging upstream (verified: no flake.nix/default.nix
  # in the repo). Using builtins.fetchGit pinned to a commit `rev` instead
  # of fetchFromGitHub: Nix verifies the fetch against that commit hash
  # directly, so there's no separate nix sha256 to compute/update by hand
  # (no `lib.fakeHash` -> build -> copy-the-real-hash dance). To bump the
  # version: `git ls-remote --tags https://github.com/marconvcm/sony-device-center.git`,
  # take the commit the new tag's `^{}` line points at (the dereferenced
  # commit, not the tag object), update `rev` (and `version`) below.
  src = builtins.fetchGit {
    url = "https://github.com/marconvcm/sony-device-center.git";
    rev = "050f9d2ea7d90f6b96e3b7dac08a9aba801bb354"; # v0.1.5
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
}
