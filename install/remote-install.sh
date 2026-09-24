#!/usr/bin/env bash
# Companion to install.sh for RAM-constrained targets (thomas-laptop's
# 8GB): install.sh's disko-install builds the whole system closure in the
# live ISO's own RAM before touching disk, which doesn't fit there. This
# does the same interactive things install.sh does -- pick a host, pick
# disk(s), set a login password, generate the agenix host key, copy this
# repo onto the installed system, generate a real hardware report -- but
# drives nixos-anywhere instead of disko-install, so evaluation and
# building happen HERE (wherever you run this from), not on the target.
#
# Run from a separate, more capable machine with Nix and SSH access to
# the live-booted target (on Windows, that means WSL2). See README
# "Installing on a low-RAM machine".
#
# Usage:
#   ./install/remote-install.sh root@<target-ip>
set -euo pipefail

TARGET="${1:?Usage: $0 <ssh-host>, e.g. root@192.168.1.50}"

NIX_FLAGS=(--extra-experimental-features "nix-command flakes" --accept-flake-config)

REPO_URL="https://github.com/UnfamousThomas/personal-nixos.git"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
REPO_DIR="$WORKDIR/personal-nixos"
echo "==> Cloning $REPO_URL"
git clone --quiet "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

echo "==> Available hosts:"
mapfile -t HOSTS < <(find hosts -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
select HOST in "${HOSTS[@]}"; do
  [ -n "${HOST:-}" ] && break
done
echo "Selected host: $HOST"

host_eval() {
  nix "${NIX_FLAGS[@]}" eval "path:${REPO_DIR}#nixosConfigurations.${HOST}.config.$1" "${@:2}"
}

# Which disk role(s) this host's disko config declares -- same as
# install.sh, read from the flake itself.
echo "==> Reading $HOST's configuration from the flake"
mapfile -t DISK_ROLES < <(
  host_eval disko.devices.disk --json --apply builtins.attrNames |
    tr -d '[]"\n\r\t ' | tr ',' '\n'
)
if [ "${#DISK_ROLES[@]}" -eq 0 ]; then
  echo "Could not determine $HOST's disk layout from the flake, aborting."
  exit 1
fi
HOST_USER="$(host_eval my.user --raw)"
HOST_UID="$(host_eval "users.users.${HOST_USER}.uid")"
HOST_HOME="$(host_eval "users.users.${HOST_USER}.home" --raw)"
HOST_GROUP="$(host_eval "users.users.${HOST_USER}.group" --raw)"
HOST_GID="$(host_eval "users.groups.${HOST_GROUP}.gid")"
PASSWORD_FILE="$(host_eval "users.users.${HOST_USER}.hashedPasswordFile" --raw)"
AGE_KEY_FILE="$(host_eval age.identityPaths --raw --apply builtins.head)"

echo "==> Block devices on $TARGET:"
ssh "$TARGET" lsblk -dpo NAME,SIZE,TYPE,TRAN,MODEL,SERIAL

# The disk the target live-booted from, if it can be identified, and the
# default suggestion for a single-disk host -- same logic as install.sh's
# best_disk, just run over SSH since the disks are on $TARGET, not here.
BOOT_DISK="$(
  ssh "$TARGET" '
    iso_src="$(findmnt -no SOURCE /iso 2>/dev/null)"
    [ -n "$iso_src" ] && echo "/dev/$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -n1)"
  ' || true
)"
best_disk() {
  ssh "$TARGET" BOOT_DISK="$BOOT_DISK" bash -s <<'REMOTE'
    best="" best_size=0
    while read -r name rm bytes type tran; do
      [ "$type" = "disk" ] || continue
      [ "$rm" = "1" ] && continue
      [ "${tran:-}" = "usb" ] && continue
      [ "$name" = "$BOOT_DISK" ] && continue
      if [ "$bytes" -gt "$best_size" ]; then
        best_size="$bytes"
        best="$name"
      fi
    done < <(lsblk -dpbno NAME,RM,SIZE,TYPE,TRAN)
    echo "$best"
REMOTE
}
DEFAULT_DISK=""
if [ "${#DISK_ROLES[@]}" -eq 1 ]; then
  DEFAULT_DISK="$(best_disk)"
fi

# Guards against picking the wrong device by mistake. The disk the target
# booted from is refused outright (wiping it would destroy the installer it
# is running from); a USB-attached or removable disk gets a warning and needs
# an explicit yes, since it's usually a stick or an external drive. Returns 1
# to send the caller back to the prompt.
check_disk_risk() {
  local disk="$1" tran rm desc ans
  if [ -n "$BOOT_DISK" ] && [ "$disk" = "$BOOT_DISK" ]; then
    echo "!! '$disk' is the disk $TARGET booted from; wiping it would destroy the installer. Pick another."
    return 1
  fi
  tran="$(ssh "$TARGET" lsblk -dno TRAN "$disk" 2>/dev/null | head -n1)"
  rm="$(ssh "$TARGET" lsblk -dno RM "$disk" 2>/dev/null | head -n1 | tr -d ' ')"
  if [ "$tran" = "usb" ] || [ "$rm" = "1" ]; then
    desc="$(ssh "$TARGET" lsblk -dno SIZE,MODEL "$disk" 2>/dev/null | head -n1)"
    echo "!! '$disk' ($desc) on $TARGET is a USB-attached or removable disk, not an internal one."
    read -rp "   Wipe it and install onto it anyway? [y/N] " ans
    case "$ans" in
      [Yy]*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

# Unlike disko-install, nixos-anywhere has no per-role --disk override
# flag -- instead, patch the chosen device straight into this throwaway
# clone's hosts/$HOST/*.nix before running nixos-anywhere against it.
# Same end result (nixos-anywhere just needs the real device already in
# the flake source it's given), same interactive picker as install.sh.
# Assumes one device per disko file, true of every host so far (a role's
# own hosts/$HOST/disko-<role>.nix if one exists, e.g. disko-bulk.nix,
# else the main hosts/$HOST/disko.nix).
disko_file_for_role() {
  local role="$1"
  if [ "$role" != "main" ] && [ -f "hosts/$HOST/disko-$role.nix" ]; then
    echo "hosts/$HOST/disko-$role.nix"
  else
    echo "hosts/$HOST/disko.nix"
  fi
}

declare -A DISKS
for role in "${DISK_ROLES[@]}"; do
  while :; do
    if [ -n "$DEFAULT_DISK" ]; then
      read -rp "Disk for '$role' on $TARGET (e.g. /dev/nvme0n1) [Enter for $DEFAULT_DISK]: " DISK
      DISK="${DISK:-$DEFAULT_DISK}"
    else
      read -rp "Disk for '$role' on $TARGET (e.g. /dev/nvme0n1): " DISK
    fi
    if ! ssh "$TARGET" test -b "$DISK"; then
      echo "'$DISK' is not a block device on $TARGET."
      continue
    fi
    for other in "${!DISKS[@]}"; do
      if [ "${DISKS[$other]}" = "$DISK" ]; then
        echo "'$DISK' is already picked for '$other'."
        continue 2
      fi
    done
    check_disk_risk "$DISK" || continue
    break
  done
  DISKS[$role]="$DISK"
  file="$(disko_file_for_role "$role")"
  if [ ! -f "$file" ]; then
    echo "Could not find a disko file for role '$role' (looked for $file), aborting."
    exit 1
  fi
  sed -i "s|device = \"[^\"]*\";|device = \"${DISK}\";|" "$file"
done

echo
echo "!! About to WIPE the following on $TARGET for host '${HOST}'. This is irreversible."
HAS_EXISTING_DATA=""
for role in "${DISK_ROLES[@]}"; do
  echo
  echo "   '$role':"
  ssh "$TARGET" lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,SERIAL,PARTLABEL,FSTYPE "${DISKS[$role]}" | sed 's/^/     /'
  if ssh "$TARGET" lsblk -rno TYPE "${DISKS[$role]}" | grep -q '^part$'; then
    HAS_EXISTING_DATA=1
  fi
done
echo
if [ -n "$HAS_EXISTING_DATA" ]; then
  echo "At least one of these disks already has partitions."
  read -rp "Type the host name ('$HOST') to wipe them and continue: " CONFIRM
  [ "$CONFIRM" = "$HOST" ] || {
    echo "Aborted."
    exit 1
  }
else
  read -rp "Type 'yes' to continue: " CONFIRM
  [ "$CONFIRM" = "yes" ] || {
    echo "Aborted."
    exit 1
  }
fi

# Files placed onto the installed system via nixos-anywhere --extra-files,
# which mirrors a local directory tree onto the target's /.
STAGE="$WORKDIR/stage"
(
  umask 077
  mkdir -p "$(dirname "$STAGE$PASSWORD_FILE")" "$(dirname "$STAGE$AGE_KEY_FILE")" "$STAGE$HOST_HOME"
)

echo
echo "==> Login password for '$HOST_USER' (also needed for sudo)"
while :; do
  read -rsp "Password: " PW1
  echo
  read -rsp "Repeat:   " PW2
  echo
  [ -n "$PW1" ] && [ "$PW1" = "$PW2" ] && break
  echo "Empty or not matching, try again."
done
(
  umask 077
  printf '%s' "$PW1" | nix "${NIX_FLAGS[@]}" shell nixpkgs#mkpasswd -c mkpasswd --method=yescrypt --stdin >"$STAGE$PASSWORD_FILE"
)
unset PW1 PW2

# The agenix key. Normally the one shared key (README "Secrets"), so secrets
# decrypt on first boot: read from $LOCAL_AGE_KEY if that file exists, else
# pasted here. Falling back to a fresh per-host key means re-encrypting the
# secrets for it.
echo "==> agenix key"
LOCAL_AGE_KEY="${PERSONAL_NIXOS_AGE_KEY:-$HOME/.config/personal-nixos/age.key}"
while :; do
  AGE_SHARED=1
  if [ -r "$LOCAL_AGE_KEY" ]; then
    echo "   using $LOCAL_AGE_KEY"
    (
      umask 077
      cp "$LOCAL_AGE_KEY" "$STAGE$AGE_KEY_FILE"
    )
  else
    read -rsp "Paste the shared age key (AGE-SECRET-KEY-1...), or Enter to generate a new one for this host: " AGE_IN
    echo
    (
      umask 077
      if [ -n "$AGE_IN" ]; then
        printf '%s\n' "$AGE_IN" >"$STAGE$AGE_KEY_FILE"
      else
        nix "${NIX_FLAGS[@]}" shell nixpkgs#age -c age-keygen -o "$STAGE$AGE_KEY_FILE" 2>/dev/null
      fi
    )
    [ -n "$AGE_IN" ] || AGE_SHARED=""
    unset AGE_IN
  fi
  if AGE_PUBKEY="$(nix "${NIX_FLAGS[@]}" shell nixpkgs#age -c age-keygen -y "$STAGE$AGE_KEY_FILE" 2>/dev/null)"; then
    break
  fi
  echo "That isn't a valid age key, try again."
  rm -f "$STAGE$AGE_KEY_FILE"
  [ ! -r "$LOCAL_AGE_KEY" ] || exit 1
done

# The copy keeps its .git, so on the installed system it's a real checkout
# (`git pull` brings in the hardware report pushed below). It can't hold that
# report itself: nixos-anywhere writes it into $REPO_DIR, after this copy.
echo "==> Staging a copy of the repo for $HOST_HOME/personal-nixos on the installed system"
cp -r "$REPO_DIR" "$STAGE$HOST_HOME/personal-nixos"

echo
echo "==> Running nixos-anywhere: generates a real hardware report, builds"
echo "    locally here (not on $TARGET), then partitions/formats/installs."
echo "    You'll be prompted for a LUKS passphrase per encrypted volume --"
echo "    pick one you'll remember, TPM2 auto-unlock can be enrolled"
echo "    afterwards, see README 'First boot'. Expect $TARGET to reboot"
echo "    partway through (kexec into a fresh installer) -- that's normal."
NIXOS_ANYWHERE_ARGS=(
  --flake "path:${REPO_DIR}#${HOST}"
  --build-on local
  --no-disko-deps
  --option accept-flake-config true
  --generate-hardware-config nixos-facter "hosts/$HOST/facter.json"
  --extra-files "$STAGE"
  --chown "$HOST_HOME/personal-nixos" "$HOST_UID:$HOST_GID"
)
nix "${NIX_FLAGS[@]}" run github:nix-community/nixos-anywhere -- "${NIXOS_ANYWHERE_ARGS[@]}" "$TARGET"

# The real hardware report only exists in $REPO_DIR, a temp directory that is
# deleted on exit, and the installed system's own copy has the placeholder.
# Push it to the repo (then `git pull` on the target), or keep a copy.
REPORT_REL="hosts/$HOST/facter.json"
REPORT_NOTE="The hardware report is unchanged from the repo's, nothing to save."
if ! git diff --quiet -- "$REPORT_REL"; then
  PUSHED=""
  read -rp "Commit and push the real hardware report to GitHub now? [y/N] " ans
  case "$ans" in
    [Yy]*)
      if git add "$REPORT_REL" &&
        git commit -q -m "hosts/$HOST: real hardware report" &&
        git push -q "git@github.com:UnfamousThomas/personal-nixos.git" HEAD:main; then
        PUSHED=1
      else
        echo "Couldn't commit/push it from here."
      fi
      ;;
  esac
  if [ -n "$PUSHED" ]; then
    REPORT_NOTE="The real hardware report is pushed. On the installed system, run:

  cd $HOST_HOME/personal-nixos && git pull"
  else
    SAVED="$HOME/$HOST-facter.json"
    cp "$REPORT_REL" "$SAVED"
    REPORT_NOTE="The real hardware report is saved at $SAVED (this machine).
The copy on the installed system still has the placeholder: put this file at
hosts/$HOST/facter.json in the repo, commit and push it, then run git pull
in $HOST_HOME/personal-nixos on the installed system. Rebuilding before that
would drop the drivers and firmware the report enables."
  fi
fi

cat <<EOF

==> Install complete.

$HOST_HOME/personal-nixos on the installed system is a checkout of this
repo.

$REPORT_NOTE

$(
  if [ -n "$AGE_SHARED" ]; then
    echo "The shared age key is in place, so secrets decrypt on first boot."
  else
    printf '%s\n\n  %s\n' "This host got its own age key. To let it decrypt the secrets, add this public key to a secrets recipient list (secrets.nix) and run agenix -r:" "$AGE_PUBKEY"
  fi
)

Also see README "First boot" for: enrolling TPM2 auto-unlock on the LUKS
volume(s) (systemd-cryptenroll), 1Password sign-in, Tailscale login, and
SSH/gh setup.
EOF
