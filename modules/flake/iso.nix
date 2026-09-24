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

          # Some routers advertise only a dead IPv6 link-local DNS server, so
          # DHCP-provided DNS would break every lookup while pings by IP work.
          # Use fixed resolvers, and stop NetworkManager and dhcpcd writing
          # /etc/resolv.conf so nothing replaces them.
          networking.nameservers = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          networking.networkmanager.dns = lib.mkForce "none";
          networking.dhcpcd.extraConfig = "nohook resolv.conf";

          # Only for a private local build (install/build-iso.sh sets this
          # and passes --impure): bakes the shared age key into the ISO so
          # the installer doesn't ask for it. Unset in CI, so the published
          # ISO never contains a key.
          environment.etc."personal-nixos/age.key" =
            let
              keyFile = builtins.getEnv "PERSONAL_NIXOS_AGE_KEY_FILE";
            in
            lib.mkIf (keyFile != "") {
              text = builtins.readFile keyFile;
              mode = "0400";
            };

          # Runs once per login shell on the main console. Gives wired
          # DHCP a while to settle. "Network" means github.com is reachable.
          # A link that answers by IP but can't resolve names gets fixed
          # resolvers written and is retried, then the installer starts. With
          # no link at all it asks (default no) whether to launch `nmtui`
          # for Wi-Fi right there.
          environment.loginShellInit = ''
            if [ "$(tty)" = "/dev/tty1" ] && [ -z "''${PERSONAL_NIXOS_INSTALL_STARTED:-}" ]; then
              export PERSONAL_NIXOS_INSTALL_STARTED=1
              echo "==> personal-nixos installer"

              have_network() {
                ${pkgs.curl}/bin/curl -fsS --max-time 2 https://github.com >/dev/null 2>&1
              }
              have_link() {
                ${pkgs.iputils}/bin/ping -c1 -W1 1.1.1.1 >/dev/null 2>&1
              }

              network=0
              link=0
              for _ in $(seq 1 20); do
                have_network && { network=1; break; }
                have_link && link=1
                sleep 1
              done

              if [ "$network" = 0 ] && [ "$link" = 1 ]; then
                echo "    Connected, but github.com won't resolve; using 1.1.1.1 / 9.9.9.9 for DNS."
                rm -f /etc/resolv.conf
                printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' > /etc/resolv.conf
                for _ in $(seq 1 5); do
                  have_network && { network=1; break; }
                  sleep 1
                done
              elif [ "$network" = 0 ]; then
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
              elif [ "$link" = 1 ]; then
                echo "    Connected, but github.com is still unreachable even with fixed DNS."
                echo "    Check the network, then run:"
                echo "    nix run github:UnfamousThomas/personal-nixos#install"
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
