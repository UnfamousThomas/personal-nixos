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
  # directly, so there's no separate nix sha256 to compute/update by hand.
  # To bump the version:
  # `git ls-remote --tags https://github.com/marconvcm/sony-device-center.git`,
  # take the commit the new tag's `^{}` line points at (the dereferenced
  # commit, not the tag object), update `rev` (and `version`) below.
  src = builtins.fetchGit {
    url = "https://github.com/marconvcm/sony-device-center.git";
    rev = "050f9d2ea7d90f6b96e3b7dac08a9aba801bb354"; # v0.1.5
  };

  # Upstream's root CMakeLists.txt adds the legacy ImGui client as a
  # subdirectory whenever Client/CMakeLists.txt exists; it needs glfw and
  # the Client/imgui git submodule, and isn't the app this package is for.
  # Only remove that file, not the whole Client/ tree: the real GUI app
  # (apps/device-center/qml.qrc) embeds its device images straight out of
  # Client/resources/devices/, so deleting the directory wholesale breaks
  # the build this package actually wants.
  postPatch = ''
    rm Client/CMakeLists.txt
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative # QtQuickControls2 lives inside qtdeclarative on Qt6
    bluez
    dbus
  ];

  # Upstream skips the GUI target with only a warning when it can't find
  # Qt; fail the build instead.
  cmakeFlags = [ "-DSONY_REQUIRE_QT=ON" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/sony-device-center
    runHook postInstallCheck
  '';

  meta = {
    description = "Linux GUI for controlling Sony Bluetooth headphones (WH-1000XM series, WF series, etc.)";
    homepage = "https://github.com/marconvcm/sony-device-center";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sony-device-center";
  };
}
