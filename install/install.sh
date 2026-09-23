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

# The live ISO's / (and /tmp) is a RAM-backed tmpfs, capped by default at
# ~50% of physical RAM. More importantly, /nix/store itself is an overlay
# of a read-only squashfs (/nix/.ro-store, part of the ISO -- always shows
# 100% used, that's normal) unioned with a *separate* writable tmpfs
# (/nix/.rw-store) that everything Nix fetches/builds during the install
# actually lands in. Evaluating this flake (many inputs: home-manager,
# disko, agenix, stylix, noctalia, opencode, openwave, treefmt-nix,
# nixos-facter) can need more room than any of these defaults leave -- well
# before physical RAM is actually exhausted -- and surfaces as a bare "No
# space left on device" mid-evaluation. Raise the caps so Nix can use the
# RAM that's actually there.
echo "==> Raising tmpfs size caps (default ~50% of RAM, easily hit mid-eval)"
for mnt in / /tmp /nix/.rw-store; do
  fstype="$(findmnt -no FSTYPE "$mnt" 2>/dev/null || true)"
  if [ "$fstype" = "tmpfs" ]; then
    sudo mount -o remount,size=90% "$mnt" || true
  fi
done

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

# Best-guess default: largest non-removable disk (skips the live-boot USB
# stick itself, which lsblk reports as removable). Only a suggestion --
# press Enter to accept it, or type a different device. The wipe
# confirmation below always shows exactly what was picked before anything
# is touched.
best_disk() {
  local exclude="${1:-}" best="" best_size=0 name rm bytes
  while read -r name rm bytes; do
    [ "$rm" = "1" ] && continue
    [ -n "$exclude" ] && [ "$name" = "$exclude" ] && continue
    if [ "$bytes" -gt "$best_size" ]; then
      best_size="$bytes"
      best="$name"
    fi
  done < <(lsblk -dpbno NAME,RM,SIZE)
  echo "$best"
}

DEFAULT_DISK="$(best_disk)"
if [ -n "$DEFAULT_DISK" ]; then
  read -rp "Target disk for the OS (e.g. /dev/nvme0n1) [Enter for $DEFAULT_DISK]: " DISK
  DISK="${DISK:-$DEFAULT_DISK}"
else
  read -rp "Target disk for the OS (e.g. /dev/nvme0n1): " DISK
fi
[ -n "$DISK" ] || {
  echo "No disk entered, aborting."
  exit 1
}
DISK2=""
if [ "$HOST" = "thomas-desktop" ]; then
  DEFAULT_DISK2="$(best_disk "$DISK")"
  if [ -n "$DEFAULT_DISK2" ]; then
    read -rp "Second disk for bulk storage (e.g. /dev/sda) [Enter for $DEFAULT_DISK2]: " DISK2
    DISK2="${DISK2:-$DEFAULT_DISK2}"
  else
    read -rp "Second disk for bulk storage (e.g. /dev/sda): " DISK2
  fi
  [ -n "$DISK2" ] || {
    echo "No second disk entered, aborting."
    exit 1
  }
fi

echo
echo "!! About to WIPE ${DISK} ${DISK2} for host '${HOST}'. This is irreversible."
read -rp "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || {
  echo "Aborted."
  exit 1
}

# Passed explicitly (not via NIX_CONFIG/nix.conf) because `sudo` strips the
# calling shell's environment, and a stock installer ISO doesn't have
# nix-command/flakes enabled system-wide. --accept-flake-config trusts this
# flake's nixConfig (nix-community/noctalia binary caches) -- without it,
# Noctalia's Quickshell/Qt6 stack gets compiled from source, which is easily
# enough to OOM a machine with 8GB of RAM.
NIX_FLAGS=(--extra-experimental-features "nix-command flakes" --accept-flake-config)

echo "==> Generating hardware report with nixos-facter"
sudo nix "${NIX_FLAGS[@]}" run github:nix-community/nixos-facter -- -o "hosts/$HOST/facter.json"

echo "==> Partitioning and formatting with disko-install"
echo "    (you will be prompted for a LUKS passphrase for each encrypted"
echo "    volume -- pick one you'll remember, you can enroll TPM2"
echo "    auto-unlock afterwards, see README 'First boot')"
DISKO_ARGS=(--flake "path:${REPO_DIR}#${HOST}" --disk main "$DISK")
if [ -n "$DISK2" ]; then
  DISKO_ARGS+=(--disk bulk "$DISK2")
fi
sudo nix "${NIX_FLAGS[@]}" run "github:nix-community/disko/latest#disko-install" -- "${DISKO_ARGS[@]}"

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
