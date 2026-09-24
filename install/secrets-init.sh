#!/usr/bin/env bash
# One-time setup of the secrets (README "Secrets"): creates the shared age
# key if it doesn't exist yet, records its public half in the repo, and
# creates the encrypted SSH key that mirror-clone uses to clone the Mirror
# repos. Safe to re-run: existing keys and secrets are left alone.
#
# Run from a checkout of this repo, on any machine with Nix.
set -euo pipefail

cd "$(dirname "$0")/.."

NIX_FLAGS=(--extra-experimental-features "nix-command flakes" --accept-flake-config)
KEY="${PERSONAL_NIXOS_AGE_KEY:-$HOME/.config/personal-nixos/age.key}"

tool() {
  nix "${NIX_FLAGS[@]}" shell nixpkgs#age nixpkgs#openssh -c "$@"
}

if [ ! -e "$KEY" ]; then
  mkdir -p "$(dirname "$KEY")"
  (
    umask 077
    tool age-keygen -o "$KEY" 2>/dev/null
  )
  cat <<EOF

Created the shared age key at $KEY

Every install needs this file (the installer reads it from here, or you
paste its AGE-SECRET-KEY line). A backup somewhere you trust is optional: if
every copy is ever lost, delete secrets/mirror-ssh.age and re-run this
script, which makes a new key and a new SSH key for GitHub.

EOF
fi

mkdir -p secrets
tool age-keygen -y "$KEY" >secrets/age-recipient.txt
echo "==> secrets/age-recipient.txt written (public key: $(cat secrets/age-recipient.txt))"

if [ -e secrets/mirror-ssh.age ]; then
  echo "==> secrets/mirror-ssh.age already exists, leaving it as is"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "==> Generating the SSH key for cloning the Mirror repos"
  tool ssh-keygen -q -t ed25519 -N "" -C "mirror-clone" -f "$TMP/key"
  tool age -r "$(cat secrets/age-recipient.txt)" -o secrets/mirror-ssh.age "$TMP/key"
  cat <<EOF

Add this public key to GitHub (Settings -> SSH and GPG keys, with access to
the MirrorStudios repos):

$(cat "$TMP/key.pub")

EOF
fi

# A flake only sees tracked files.
if git rev-parse --git-dir >/dev/null 2>&1; then
  git add secrets/age-recipient.txt secrets/mirror-ssh.age
  echo "==> Staged secrets/. Commit and push them."
fi

cat <<EOF

On an already-installed machine, switch it to the shared key, then rebuild:

  sudo install -m 600 -o root -g root "$KEY" /var/lib/agenix/host.key
EOF
