#!/usr/bin/env bash
# Interactive installer: boot the NixOS ISO, run this, pick a host and its
# disk(s), and it generates a hardware report via nixos-facter,
# partitions/formats via disko and installs from this flake.
#
# Usage (from the live ISO):
#   nix --extra-experimental-features "nix-command flakes" run "github:UnfamousThomas/personal-nixos#install"
# or, from a checkout of this repo:
#   ./install/install.sh
set -euo pipefail

# Only ever used on this repo's own flake: --accept-flake-config trusts its
# nixConfig (binary caches). Passed explicitly, not via NIX_CONFIG/nix.conf,
# because `sudo` strips the calling environment and a stock installer ISO
# doesn't have nix-command/flakes enabled.
NIX_FLAGS=(--extra-experimental-features "nix-command flakes" --accept-flake-config)

# The flake app (modules/flake/install-app.nix) provides the pinned tools
# and the source tree to install. Run from a checkout, hand off to it.
if [ -z "${DISKO_INSTALL:-}" ]; then
  exec nix "${NIX_FLAGS[@]}" run "path:$(cd "$(dirname "$0")/.." && pwd)#install"
fi

# The live ISO's / (and /tmp) is a RAM-backed tmpfs, capped by default at
# ~50% of physical RAM. More importantly, /nix/store itself is an overlay
# of a read-only squashfs (/nix/.ro-store, part of the ISO -- always shows
# 100% used, that's normal) unioned with a *separate* writable tmpfs
# (/nix/.rw-store) that everything Nix fetches/builds during the install
# actually lands in. Evaluating and building this flake can need more room
# than any of these defaults leave -- well before physical RAM is actually
# exhausted -- and surfaces as a bare "No space left on device". Raise the
# caps so Nix can use the RAM that's actually there.
echo "==> Raising tmpfs size caps (default ~50% of RAM, easily hit mid-eval)"
for mnt in / /tmp /nix/.rw-store; do
  fstype="$(findmnt -no FSTYPE "$mnt" 2>/dev/null || true)"
  if [ "$fstype" = "tmpfs" ]; then
    sudo mount -o remount,size=90% "$mnt" || true
  fi
done

REPO_URL="https://github.com/UnfamousThomas/personal-nixos.git"

# A writable copy of the exact source this app was built from. It gets the
# real hardware report and is copied onto the installed system.
WORKDIR="$(mktemp -d)"
REPO_DIR="$WORKDIR/personal-nixos"
echo "==> Copying flake source"
# shellcheck disable=SC2153 # set by the flake app, like DISKO_INSTALL
cp -r "$REPO_SRC" "$REPO_DIR"
chmod -R u+w "$REPO_DIR"
cd "$REPO_DIR"

echo "==> Available hosts:"
mapfile -t HOSTS < <(find hosts -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
select HOST in "${HOSTS[@]}"; do
  [ -n "${HOST:-}" ] && break
done
echo "Selected host: $HOST"

host_eval() {
  sudo nix "${NIX_FLAGS[@]}" eval "path:${REPO_DIR}#nixosConfigurations.${HOST}.config.$1" "${@:2}"
}

# Which disk role(s) this host's disko config declares (e.g. just "main",
# or "main" + "bulk") -- read from the flake itself, so any host with any
# number of disks just works, and a host that drops a disk (see
# thomas-desktop's host.bulkDisk.enable) is only asked about the ones it
# actually needs.
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
PASSWORD_FILE="$(host_eval "users.users.${HOST_USER}.hashedPasswordFile" --raw)"
AGE_KEY_FILE="$(host_eval age.identityPaths --raw --apply builtins.head)"

echo "==> Block devices:"
lsblk -dpo NAME,SIZE,TYPE,TRAN,MODEL,SERIAL

# The disk the live ISO booted from, if it can be identified.
BOOT_DISK=""
if iso_src="$(findmnt -no SOURCE /iso 2>/dev/null)" && [ -n "$iso_src" ]; then
  BOOT_DISK="/dev/$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -n1)"
fi

# Default suggestion for a single-disk host: the largest internal disk.
# Skips removable and USB-attached disks and the ISO's own boot disk.
best_disk() {
  local best="" best_size=0 name rm bytes type tran
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
}

# Guards against picking the wrong device by mistake. The disk the installer
# booted from is refused outright (wiping it would destroy the installer);
# a USB-attached or removable disk gets a warning and needs an explicit yes,
# since it's usually a stick or an external drive, not an internal disk.
# Returns 1 to send the caller back to the prompt.
check_disk_risk() {
  local disk="$1" tran rm desc ans
  if [ -n "$BOOT_DISK" ] && [ "$disk" = "$BOOT_DISK" ]; then
    echo "!! '$disk' is the disk this installer booted from; wiping it would destroy the installer. Pick another."
    return 1
  fi
  tran="$(lsblk -dno TRAN "$disk" 2>/dev/null | head -n1)"
  rm="$(lsblk -dno RM "$disk" 2>/dev/null | head -n1 | tr -d ' ')"
  if [ "$tran" = "usb" ] || [ "$rm" = "1" ]; then
    desc="$(lsblk -dno SIZE,MODEL "$disk" 2>/dev/null | head -n1)"
    echo "!! '$disk' ($desc) is a USB-attached or removable disk, not an internal one."
    read -rp "   Wipe it and install onto it anyway? [y/N] " ans
    case "$ans" in
      [Yy]*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

# With more than one role there is no default: the right disk for each
# role can't be guessed from sizes.
DEFAULT_DISK=""
if [ "${#DISK_ROLES[@]}" -eq 1 ]; then
  DEFAULT_DISK="$(best_disk)"
fi

declare -A DISKS
for role in "${DISK_ROLES[@]}"; do
  while :; do
    if [ -n "$DEFAULT_DISK" ]; then
      read -rp "Disk for '$role' (e.g. /dev/nvme0n1) [Enter for $DEFAULT_DISK]: " DISK
      DISK="${DISK:-$DEFAULT_DISK}"
    else
      read -rp "Disk for '$role' (e.g. /dev/nvme0n1): " DISK
    fi
    if [ ! -b "$DISK" ]; then
      echo "'$DISK' is not a block device."
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
done

echo
echo "!! About to WIPE the following for host '${HOST}'. This is irreversible."
HAS_EXISTING_DATA=""
for role in "${DISK_ROLES[@]}"; do
  echo
  echo "   '$role':"
  lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,SERIAL,PARTLABEL,FSTYPE "${DISKS[$role]}" | sed 's/^/     /'
  if lsblk -rno TYPE "${DISKS[$role]}" | grep -q '^part$'; then
    HAS_EXISTING_DATA=1
  fi
done
echo
# A disk that already has partitions (e.g. an existing install of this
# host) needs a deliberate answer, not a reflexive "yes".
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

# Files placed onto the installed system. Created here as the ISO user,
# handed to root below.
STAGE="$WORKDIR/stage"
(
  umask 077
  mkdir -p "$STAGE"
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
  printf '%s' "$PW1" | mkpasswd --method=yescrypt --stdin >"$STAGE/password"
)
unset PW1 PW2

# The agenix key. Normally the one shared key (README "Secrets"), so secrets
# decrypt on first boot: baked into a locally built ISO, or pasted here.
# Falling back to a fresh per-host key means re-encrypting the secrets for it.
echo "==> agenix key"
ISO_AGE_KEY=/etc/personal-nixos/age.key
while :; do
  AGE_SHARED=1
  if [ -r "$ISO_AGE_KEY" ]; then
    echo "   using the key baked into this ISO"
    (
      umask 077
      cp "$ISO_AGE_KEY" "$STAGE/host.key"
    )
  else
    read -rsp "Paste the shared age key (AGE-SECRET-KEY-1...), or Enter to generate a new one for this host: " AGE_IN
    echo
    (
      umask 077
      if [ -n "$AGE_IN" ]; then
        printf '%s\n' "$AGE_IN" >"$STAGE/host.key"
      else
        age-keygen -o "$STAGE/host.key" 2>/dev/null
      fi
    )
    [ -n "$AGE_IN" ] || AGE_SHARED=""
    unset AGE_IN
  fi
  if AGE_PUBKEY="$(age-keygen -y "$STAGE/host.key" 2>/dev/null)"; then
    break
  fi
  echo "That isn't a valid age key, try again."
  rm -f "$STAGE/host.key"
  [ ! -r "$ISO_AGE_KEY" ] || exit 1
done
sudo chown -R root:root "$STAGE"

echo "==> Generating hardware report with nixos-facter"
sudo "$NIXOS_FACTER" -o "hosts/$HOST/facter.json"

# Turn the copy into a checkout of the installed commit, so the new
# facter.json shows up as the only change. Skipped when the source has no
# commit (a dirty local checkout).
if [ -n "${REPO_REV:-}" ]; then
  git init -q -b main
  git remote add origin "$REPO_URL"
  if git fetch -q --depth 1 origin "$REPO_REV"; then
    git reset -q FETCH_HEAD
  else
    echo "   (couldn't fetch $REPO_REV; the copy on the new system won't be a git checkout)"
    rm -rf .git
  fi
fi
sudo chown -R "$HOST_UID:users" "$REPO_DIR"

echo "==> Partitioning, formatting and installing with disko-install"
echo "    (you will be prompted for a LUKS passphrase for each encrypted"
echo "    volume -- pick one you'll remember, you can enroll TPM2"
echo "    auto-unlock afterwards, see README 'First boot')"
DISKO_ARGS=(
  --flake "path:${REPO_DIR}#${HOST}"
  --option extra-experimental-features "nix-command flakes"
  --option extra-substituters "$EXTRA_SUBSTITUTERS"
  --option extra-trusted-public-keys "$EXTRA_TRUSTED_PUBLIC_KEYS"
  --extra-files "$STAGE/password" "$PASSWORD_FILE"
  --extra-files "$STAGE/host.key" "$AGE_KEY_FILE"
  --extra-files "$REPO_DIR" "$HOST_HOME/personal-nixos"
)
for role in "${DISK_ROLES[@]}"; do
  DISKO_ARGS+=(--disk "$role" "${DISKS[$role]}")
done
sudo "$DISKO_INSTALL" "${DISKO_ARGS[@]}"

cat <<EOF

==> Install complete.

This machine's repo checkout, with its real hardware report
(hosts/$HOST/facter.json), is at ~/personal-nixos on the installed system.
Commit and push it after first boot, once GitHub access is set up (README
"First boot"):

  cd ~/personal-nixos
  git add hosts/$HOST/facter.json
  git commit -m "hosts/$HOST: real hardware report"
  git push origin HEAD:main

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
