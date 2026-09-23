{ inputs, config, ... }:
{
  # `nix build .#iso` -- a plain NixOS installer ISO (not a real host, so
  # it lives here rather than under hosts/) with nix-command/flakes already
  # enabled and a login hook that runs the installer automatically, so
  # booting it is the entire "get networking up, run the installer" dance
  # from the README's "Installing on a new machine" section.
  flake.nixosConfigurations.installer-iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      (
        { pkgs, lib, ... }:
        {
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          # installation-device.nix (pulled in by installation-cd-minimal.nix)
          # already sets this to "nixos" as a plain assignment, not
          # mkDefault -- needs mkForce, not just a later definition, to win.
          services.getty.autologinUser = lib.mkForce "root";

          # Runs once per login shell on the main console. Gives wired
          # DHCP a few seconds to settle; if nothing's up by then, asks
          # (default no) whether to launch `nmtui` for Wi-Fi right there,
          # rather than silently timing out and making you re-type the
          # install command yourself afterwards.
          environment.loginShellInit = ''
            if [ "$(tty)" = "/dev/tty1" ] && [ -z "''${PERSONAL_NIXOS_INSTALL_STARTED:-}" ]; then
              export PERSONAL_NIXOS_INSTALL_STARTED=1
              echo "==> personal-nixos installer"

              have_network() {
                ${pkgs.curl}/bin/curl -fsS --max-time 2 https://github.com >/dev/null 2>&1
              }

              network=0
              for _ in $(seq 1 5); do
                have_network && { network=1; break; }
                sleep 1
              done

              if [ "$network" = 0 ]; then
                read -rp "No network detected. Connect via Wi-Fi now? [y/N] " ans
                case "$ans" in
                  [Yy]*)
                    nmtui
                    echo "    waiting for network..."
                    for _ in $(seq 1 20); do
                      have_network && { network=1; break; }
                      sleep 1
                    done
                    ;;
                esac
              fi

              if [ "$network" = 1 ]; then
                nix run github:UnfamousThomas/personal-nixos#install
              else
                echo "    still no network -- bring it up (nmtui), then run:"
                echo "    nix run github:UnfamousThomas/personal-nixos#install"
              fi
            fi
          '';
        }
      )
    ];
  };

  perSystem = _: {
    packages.iso = config.flake.nixosConfigurations.installer-iso.config.system.build.isoImage;
  };
}
