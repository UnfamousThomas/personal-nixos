#!/usr/bin/env bash
# Builds a PRIVATE installer ISO with the shared age key baked in, so the
# installer never asks for it. Local only: the ISO contains the key, so never
# upload it or share it (the GitHub workflow builds the public one, without).
#
# Run from a checkout of this repo, on a machine with Nix (WSL is fine).
# The key comes from $PERSONAL_NIXOS_AGE_KEY or ~/.config/personal-nixos/age.key
# (created by install/secrets-init.sh, or paste it there from 1Password).
#
# Usage: install/build-iso.sh [output.iso]
set -euo pipefail

cd "$(dirname "$0")/.."

KEY="${PERSONAL_NIXOS_AGE_KEY:-$HOME/.config/personal-nixos/age.key}"
OUT="${1:-personal-nixos-installer-PRIVATE.iso}"

if [ ! -r "$KEY" ]; then
  echo "No age key at $KEY. Run install/secrets-init.sh, or put your key there." >&2
  exit 1
fi

echo "==> Building the ISO (impure, so it can read $KEY)"
ISO_DIR="$(
  PERSONAL_NIXOS_AGE_KEY_FILE="$KEY" nix \
    --extra-experimental-features "nix-command flakes" --accept-flake-config \
    build --impure --no-link --print-out-paths .#iso
)"

cp "$ISO_DIR"/iso/*.iso "$OUT"
chmod 600 "$OUT"

cat <<EOF

==> Wrote $OUT

It contains the age key: don't upload or share it. Write it to a USB stick
yourself (Rufus/dd). The key also sits in this machine's /nix/store, readable
by its other users; on a shared machine, delete it afterwards with:

  nix store delete $ISO_DIR
EOF
