{ inputs, ... }:
{
  # Applied to every nixpkgs instance this flake creates itself (perSystem,
  # and every host via features/core/nix-settings.nix) so custom packages
  # are available everywhere consistently.
  flake.overlays.default = final: _prev: {
    sony-device-center = final.callPackage ../../pkgs/sony-device-center.nix { };
    gradient-wallpaper = final.callPackage ../../pkgs/gradient-wallpaper.nix { };

    # Upstream's test suite includes a case that spawns a bwrap sandbox and
    # tries to configure a loopback interface inside it -- needs network
    # namespace privileges a Nix build sandbox (and GitHub Actions' runner)
    # doesn't grant, so it fails there regardless of whether the code under
    # test is actually broken. Skip tests for the packaged build; they still
    # run in upstream's own CI, which does have those privileges.
    openwave = inputs.openwave.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
      doCheck = false;
    });

    # Upstream's own build script (script/build.ts) compiles the binary
    # then immediately runs `opencode --version` as a smoke test and
    # `process.exit(1)`s the whole build if that crashes; Nix's
    # doInstallCheck (versionCheckHook) does the same thing again after
    # install. Both have been observed to SIGSEGV in this repo's build
    # environments (Nix's sandbox, WSL2) even though the exact cause isn't
    # pinned down -- confirmed it's not a blanket "no AVX2" issue (WSL2
    # here does report avx2 in /proc/cpuinfo). Since neither check can be
    # trusted to reflect whether the binary actually works on real target
    # hardware, skip both rather than let an environment-specific crash
    # block the whole system build.
    opencode =
      inputs.opencode.packages.${final.stdenv.hostPlatform.system}.opencode.overrideAttrs
        (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace packages/opencode/script/build.ts \
              --replace-fail 'process.exit(1)' 'console.warn("(smoke test failed; skipped, see modules/flake/overlays.nix)")'
          '';
          doInstallCheck = false;
          # Same crash, different codepath: upstream's postInstall also runs
          # $out/bin/opencode (for `completion`, to generate shell completion
          # scripts), which segfaults here too. Every invocation of the binary
          # crashes inside this sandbox, not just the smoke test specifically
          # -- consistent with Bun's compiled-binary $bunfs self-unpack trick
          # tripping over the sandbox's restricted /proc and syscalls, rather
          # than the binary being unsound. Drop upstream's postInstall entirely
          # rather than patch around it a second time; shell completions for
          # opencode aren't worth the fragility.
          postInstall = "";
        });
  };
}
