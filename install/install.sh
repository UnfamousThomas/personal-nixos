#!/usr/bin/env bash
# Interactive installer: boot the NixOS ISO, run this, pick a host and a
# disk, and it partitions/formats via disko, generates a hardware report
# via nixos-facter, and installs from this flake.
#
# Usage (from the live ISO, as root or with sudo):
#   nix run "github:UnfamousThomas/personal-nixos#install"
# or, having cloned the repo yourself:
#   ./install/install.sh
set -euo pipefail

REPO_URL="https://github.com/UnfamousThomas/personal-nixos.git"

if [ -d "$(dirname "$0")/../.git" ]; then
  REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
  echo "==> Using existing checkout at $REPO_DIR"
else
  WORKDIR="$(mktemp -d)"
  REPO_DIR="$WORKDIR/personal-nixos"
  echo "==> Cloning $REPO_URL"
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

echo "==> Available hosts:"
mapfile -t HOSTS < <(find hosts -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
select HOST in "${HOSTS[@]}"; do
  [ -n "${HOST:-}" ] && break
done
echo "Selected host: $HOST"

echo "==> Block devices:"
lsblk -dpno NAME,SIZE,MODEL

read -rp "Target disk for the OS (e.g. /dev/nvme0n1): " DISK
DISK2=""
if [ "$HOST" = "thomas-desktop" ]; then
  read -rp "Second disk for bulk storage (e.g. /dev/sda): " DISK2
fi

echo
echo "!! About to WIPE ${DISK} ${DISK2} for host '${HOST}'. This is irreversible."
read -rp "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || {
  echo "Aborted."
  exit 1
}

echo "==> Generating hardware report with nixos-facter"
sudo nix run github:nix-community/nixos-facter -- -o "hosts/$HOST/facter.json"

echo "==> Partitioning and formatting with disko-install"
echo "    (you will be prompted for a LUKS passphrase for each encrypted"
echo "    volume -- pick one you'll remember, you can enroll TPM2"
echo "    auto-unlock afterwards, see README 'First boot')"
DISKO_ARGS=(--flake "path:${REPO_DIR}#${HOST}" --disk main "$DISK")
if [ -n "$DISK2" ]; then
  DISKO_ARGS+=(--disk bulk "$DISK2")
fi
sudo nix run "github:nix-community/disko/latest#disko-install" -- "${DISKO_ARGS[@]}"

cat <<EOF

==> Install complete.

IMPORTANT -- hosts/$HOST/facter.json in $REPO_DIR now reflects this
machine's real hardware, but that only exists in this temporary checkout.
Before you do anything else:

  cd "$REPO_DIR"
  git add "hosts/$HOST/facter.json"
  git commit -m "hosts/$HOST: real hardware report"
  git push

...or the next rebuild will silently fall back to the placeholder RAM
figure baked into the repo, and re-partition-sized values (swap) will be
wrong on a reinstall.

Also see README "First boot" for: enrolling TPM2 auto-unlock on the LUKS
volume(s) (systemd-cryptenroll), agenix key bootstrap, 1Password sign-in,
Tailscale login, and SSH/gh setup.
EOF
