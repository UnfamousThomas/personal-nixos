# personal-nixos

Thomas's personal, reproducible, multi-host NixOS configuration. Flake-based,
tracks `nixos-unstable`, built with [flake-parts](https://flake.parts) using
the [Dendritic pattern](https://github.com/mightyiam/dendritic): every file
under `modules/` is itself a flake-parts module (auto-discovered via
[import-tree](https://github.com/vic/import-tree)), and each feature
contributes whatever it needs to NixOS and/or Home Manager from a single
file, instead of being split across separate `nixos/`/`home/` trees.

Hosts: `thomas-laptop`, `thomas-desktop`. User: `thomaspalts` (the
`my.user` option). Shared config by default; host-specific things (laptop
power/touchpad, dual-disk desktop layout) only where they actually differ.

## Structure

```
flake.nix                    inputs + `import-tree ./modules`
modules/
  flake/                      flake-parts infrastructure itself
    flake-parts.nix           enables the flake.modules.* option namespace
    nixpkgs.nix, overlays.nix perSystem pkgs, allowUnfree, custom package overlay
    packages.nix              custom packages as flake outputs + checks
    formatter.nix             treefmt-nix: nixfmt + statix + deadnix
    devshell.nix              `nix develop` here: tools for maintaining this repo
    hosts.nix                 turns every hosts/<name>/ into nixosConfigurations.<name>
    iso.nix                   installer-iso host + `packages.iso` (auto-runs the installer on boot)
    templates.nix, install-app.nix
  roles/                      base, workstation, gaming, laptop: bundles of features
  features/                   the actual configuration, one aspect per file
    core/                     options (my.user), hardware report, nix settings,
                                locale, users, boot, networking, home-manager
                                wiring, zram
    security/                 agenix, Estonian ID card
    desktop/                  niri, greetd, noctalia, stylix, bluetooth, audio
    terminal/                 ghostty, zsh+starship, CLI tools
    browser/                  firefox
    apps/                     git, gh, ssh, 1Password, devenv, docker, tailscale,
                                discord, sony-device-center, openwave, zed/
    gaming/                   steam, minecraft
    laptop/                   power, touchpad (laptop-only)
hosts/
  thomas-laptop/              default.nix (the host module), disko.nix, facter.json
  thomas-desktop/             same, plus disko-bulk.nix (the optional HDD)
pkgs/                         custom derivations (sony-device-center, gradient-wallpaper)
install/install.sh            interactive installer
templates/devenv-project/     `nix flake init -t` template for new projects
secrets.nix                   agenix: secret -> which keys may decrypt it
.github/workflows/check.yml   CI: flake check + building both hosts
```

### How a host is assembled

Each feature file declares `flake.modules.nixos.<name>` and/or
`flake.modules.homeManager.<name>`. Roles (`modules/roles/`) bundle
features: each role is a NixOS module that imports its NixOS features and
adds its Home Manager features to `home-manager.users.<my.user>`. A host's
`hosts/<name>/default.nix` defines `flake.modules.nixos.<name>`, which
imports roles plus anything host-specific:

```nix
flake.modules.nixos.thomas-laptop = { config, ... }: {
  imports = [ nixos.base nixos.workstation nixos.gaming nixos.laptop nixos.openwave ./disko.nix ];
  hardware.facter.reportPath = ./facter.json;
  system.stateVersion = "26.05";
  home-manager.users.${config.my.user}.home.stateVersion = "26.05";
};
```

`modules/flake/hosts.nix` finds every directory under `hosts/` and builds
`nixosConfigurations.<name>` from that module, with `networking.hostName`
set to the directory name.

## Adding a new host

1. Copy `hosts/thomas-laptop/` to `hosts/<name>/`.
2. In `default.nix`, rename the module to `flake.modules.nixos.<name>`,
   pick the roles, and set both `stateVersion`s to the NixOS release you are
   installing (never bump them later).
3. Adjust `disko.nix` (disk layout; give the partitions `<name>-` labels).
4. Keep the placeholder `facter.json`; the installer replaces it with the
   real report.

## Adding a new feature module

Create `modules/features/<category>/<name>.nix`:

```nix
{
  flake.modules.nixos.my-feature = { pkgs, ... }: { ... };      # if it needs system-level config
  flake.modules.homeManager.my-feature = { pkgs, ... }: { ... }; # if it needs user-level config
}
```

If it needs an upstream flake as a module, capture `inputs` in the outer
function and `imports = [ inputs.foo.nixosModules.default ];` inside the
inner module (see `modules/features/security/agenix.nix` for the pattern).
Then add it to a role in `modules/roles/`, or import it directly from the
host(s) that should have it.

## Installing on a new machine

**This wipes the target disk(s).** Test in a VM first if you're not sure
about something (see "Testing before you commit to real hardware" below).

Either boot the stock NixOS ISO and follow the steps below, or build this
repo's own installer ISO (`nix build .#iso`, or download it from this
repo's "Installer ISO (latest)" GitHub release -- built on demand via the
"build installer ISO" Actions workflow, not on every push) and boot that
instead: it has `nix-command`/`flakes` already enabled and launches the
installer automatically once networking is up, skipping steps 1-2 below
entirely.

1. Boot the NixOS ISO on the target machine, get networking up. If you need
   a non-US keyboard layout (e.g. Estonian) and `loadkeys ee` fails with "no
   such file or directory", the ISO's built-in `kbd` is a trimmed-down copy
   missing that keymap -- pull the full package from nixpkgs instead:
   ```
   nix --extra-experimental-features "nix-command flakes" shell nixpkgs#kbd -c loadkeys ee
   ```
2. Run (the installer ISO doesn't have `nix-command`/`flakes` enabled by
   default, hence the flag):
   ```
   nix --extra-experimental-features "nix-command flakes" run "github:UnfamousThomas/personal-nixos#install"
   ```
   (or clone the repo and run `./install/install.sh`, which runs the same
   app from the checkout). Add `--refresh` if you're re-running right after
   pushing a fix, so it doesn't reuse a cached fetch of an older commit.
   The installer uses the disko and nixos-facter versions from
   `flake.lock`, and installs exactly the commit you ran. It raises the live
   ISO's tmpfs size cap (default ~50% of RAM) first, since building the
   system can otherwise fail with a bare "No space left on device" well
   before RAM is actually full. That fix only goes so far, though: on a
   genuinely low-RAM machine (`thomas-laptop`'s 8GB, for one) the build
   still runs entirely in the live ISO's memory, and no realistic amount of
   swap fixes that cleanly -- see "Installing on a low-RAM machine" below
   for what actually works.
3. Pick the host. The script reads that host's disko config from the flake
   to find which disk role(s) it needs (e.g. just `main`, or `main` +
   `bulk`) and asks for a device per role. For a single-disk host it
   suggests the largest internal disk (never a USB or removable disk or the
   ISO's boot disk); with several roles you pick each one explicitly. It
   then shows each disk's model, serial and existing partitions before
   anything is touched. If a disk already has partitions you must type the
   host name, not just `yes`.
   - `thomas-desktop` normally wants two disks (OS SSD + bulk HDD). If the
     HDD isn't connected yet, set `host.bulkDisk.enable = false` in
     `hosts/thomas-desktop/default.nix`, commit and push it, *then* run the
     installer: it only asks for `main`. See "Adding the bulk disk later".
4. It asks for the user's login password, generates the host's agenix key
   and a hardware report (`nixos-facter`), then partitions, formats and
   installs. You'll be prompted for a LUKS passphrase per encrypted volume;
   pick one you'll remember, TPM2 auto-unlock gets enrolled afterwards (see
   "First boot" below).
5. The installed system has the repo at `~/personal-nixos`, with the real
   `hosts/<host>/facter.json` as an uncommitted change. Commit and push it
   after first boot (the installer prints the commands). Until it's
   committed, rebuilding from GitHub uses the placeholder and warns that
   firmware and drivers aren't being configured.

### Installing on a low-RAM machine

The installer above builds the entire system closure in the live ISO's
own RAM before it ever touches the target disk. Raising the tmpfs cap
(step 2) helps when the machine is hitting an artificial ~50%-of-RAM
quota with headroom to spare, but it can't manufacture RAM that isn't
there. `thomas-laptop` has 8GB, and its closure (Steam, the full Qt5 +
Qt6 stack, Docker, a browser, ...) is comfortably bigger than that once
unpacked. Swap doesn't reliably save you here either: the obvious place
to put it is the target disk, but disko wipes that the moment it formats,
and the live boot USB usually can't be repartitioned safely while it's
mounted and in use.

The real fix is to not build on the target machine at all. Drive the
install from a second, more capable machine with
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere): it
builds locally there and only copies the finished closure to the target
over SSH.

`thomas-laptop/disko.nix` has its device hardcoded (`/dev/nvme0n1`, its
only disk) specifically so this needs no local edits -- unlike
`disko-install --disk`, nixos-anywhere has no per-role disk-override
flag. `thomas-desktop` still has the `CHANGE_ME_SSD`/`CHANGE_ME_HDD`
placeholders in its `disko.nix`; hardcode the real device path(s) there
first if you ever need to do this on the desktop.

`install/remote-install.sh` is `install.sh`'s companion for exactly this:
run it from the other machine (needs Nix -- on Windows that means WSL2),
not the target. It does the same interactive things `install.sh` does --
pick a host, pick disk(s), prompt for a login password, generate the
agenix host key, generate a real hardware report, copy this repo onto the
installed system -- but drives `nixos-anywhere` instead of `disko-install`,
so the build happens on the machine running the script, not the target.

1. On the live-booted target: `passwd` (sets a temporary root password,
   gone on next reboot) and `ip a` (its LAN IP). Then, from the other
   machine: `ssh-copy-id root@<ip>`.
2. Run it (clones a fresh temporary checkout itself, no local checkout
   needed):
   ```
   curl -O https://raw.githubusercontent.com/UnfamousThomas/personal-nixos/main/install/remote-install.sh
   chmod +x remote-install.sh
   ./remote-install.sh root@<ip>
   ```
3. Same prompts as `install.sh`: pick the host, pick disk(s) (shown over
   SSH from the target), confirm the wipe, set a login password. The
   target reboots partway through -- `nixos-anywhere` kexecs it into a
   fresh minimal installer before formatting -- that's expected, not a
   failure.
4. Prints the same "commit and push the real hardware report" reminder
   and agenix public key as `install.sh` at the end. The repo copy on the
   installed system is at whatever `my.user`'s home directory is (e.g.
   `~thomaspalts/personal-nixos`).

`--build-on local` (baked into the script) is the whole point: it keeps
evaluation and building on the machine running the script instead of the
RAM-starved target. `--no-disko-deps` skips uploading disko's own
dependency closure to the target, trimming what still has to fit there.

### Adding the bulk disk later (thomas-desktop)

Never re-run the installer for this: it reformats the SSD too. Format just
the HDD with the locked disko, from `~/personal-nixos`:

```
sudo nix run .#disko -- --mode destroy,format,mount --root-mountpoint / \
  --argstr device /dev/disk/by-id/<the-hdd> hosts/thomas-desktop/disko-bulk.nix
```

Then set `host.bulkDisk.enable = true`, `sudo nixos-rebuild switch --flake
.#thomas-desktop`, and enroll the TPM for it (next section). The HDD is
unlocked after boot rather than in the initrd, with `nofail`, so a missing
or dead HDD never stops the desktop from booting.

## First boot

Log in as `thomaspalts` with the password you gave the installer.

1. **TPM2 auto-unlock**: for each LUKS volume on the host (`cryptroot`, and
   `cryptswap`/`cryptbulk` where present), enroll the TPM:
   ```
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-partlabel/<host>-<root|swap|bulk>
   ```
   Reboot and confirm it unlocks without a passphrase prompt. If it doesn't
   (e.g. after a firmware update invalidates the PCR measurements), you'll
   fall back to the passphrase prompt; re-enroll with the command above.

   Known limit: PCRs 0+2+7 don't measure the kernel command line or the
   initrd, which sit unsigned on the unencrypted ESP. The boot menu editor
   is disabled, but someone with physical access who replaces the initrd on
   the ESP still gets the disk unlocked by the TPM. Closing that needs a
   TPM PIN (`--tpm2-with-pin=yes`) or Secure Boot with signed images
   (lanzaboote).
2. **Hibernate (laptop only)**: the lid suspends, then hibernates after 2h
   (`features/laptop/power.nix`). Try `systemctl hibernate` and confirm it
   resumes cleanly: disko's own swap module flags encrypted-swap + resume as
   not fully supported upstream (see comments in
   `hosts/thomas-laptop/disko.nix`). The swap partition is 8 GiB, sized for
   8 GiB of RAM.
3. **1Password**: sign in on first launch (autostarts via niri). Enable the
   SSH agent and, if your existing SSH key is Ed25519 or RSA, import it
   (Settings → Developer → SSH Agent) so `programs.ssh`'s `IdentityAgent`
   picks it up. For commit signing, set `programs.git.signing.key` to the
   key's public half and `signByDefault = true` in `apps/onepassword.nix`.
   Turn on "Connect with 1Password in the browser" in the app so the
   Firefox extension pairs with it.
4. **Tailscale**: `sudo tailscale up`, follow the browser login link.
   MagicDNS works automatically once authenticated (systemd-resolved is
   already the resolver).
5. **SSH keys**: if you're bringing an existing key over as a file, copy
   `~/.ssh/id_ed25519{,.pub}` into place and `chmod 600` the private key.
6. **gh auth**: `gh auth login` (interactive OAuth device flow, no secret
   needed). Then commit and push `hosts/<host>/facter.json` from
   `~/personal-nixos`.

## Rebuilding after changes

```
sudo nixos-rebuild switch --flake .#thomas-laptop   # or #thomas-desktop
```

Run from a checkout of this repo (`~/personal-nixos`). Running
`nix flake check` first catches evaluation errors and broken custom
packages without building a whole system.

## Testing before you commit to real hardware

- `nix flake check`: evaluates both hosts and every `flake.modules.*`
  entry, and builds `checks.*` (the custom packages, treefmt, shellcheck of
  the installer). It does not build a full system.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`:
  builds the whole system. CI (`.github/workflows/check.yml`) does both of
  these for both hosts on every push.
- `nix build .#sony-device-center` (or `.#gradient-wallpaper`): one custom
  package on its own.
- `sudo nixos-rebuild build-vm --flake .#thomas-desktop` then run the
  resulting `./result/bin/run-*-vm`: boots the config in a VM so you can
  poke at Niri/Noctalia/theming without touching real hardware. This
  bypasses disko/LUKS entirely (the VM gets a plain virtual disk), so it
  won't catch disk-layout mistakes.
- For the disk layout itself, disko has its own VM test tooling
  (`nix run .#disko -- --mode disko --dry-run ...` and disko's
  `disko-tests` flow).

## Secrets (agenix)

`secrets.nix` at the repo root lists, per encrypted file under `secrets/`,
which age public keys may decrypt it. Nothing sensitive is ever committed
in plaintext, only `.age` files and the public-key list.

- **Host keys**: each host has its own age key at
  `/var/lib/agenix/host.key`, generated by the installer, which prints the
  public half. Later: `sudo age-keygen -y /var/lib/agenix/host.key`.
  NixOS-level secrets decrypt with it.
- **User key**: Home-Manager-level secrets (wired via `sharedModules` in
  `core/home-manager.nix`) decrypt with `~/.config/age/keys.txt`. Create it
  once per machine with `age-keygen -o ~/.config/age/keys.txt` and add its
  public half (`age-keygen -y ~/.config/age/keys.txt`) to `secrets.nix`.

Adding a secret: list the recipients on it in `secrets.nix`, `agenix -e
secrets/<name>.age` to write it (needs the private key of at least one
already-listed recipient), commit `secrets.nix` and `secrets/*.age`, then
rebuild the host(s) that need it. After adding a new host or key to an
existing secret, `agenix -r` re-encrypts every secret against the current
key list; commit the result.

## Binary cache keys

`nix-community.cachix.org` and `noctalia.cachix.org` are trusted in both
`flake.nix` (`nixConfig`, used while installing) and
`features/core/nix-settings.nix`. If a key ever rotates, substitution fails
with signature errors. Get the current key from Cachix and update both
places:

```
curl -s https://app.cachix.org/api/v1/cache/noctalia | jq -r '.publicSigningKeys[]'
```

## Custom / self-maintained packages

Most things come straight from nixpkgs. These don't:

| Package | Source | Why | Updating |
|---|---|---|---|
| `sony-device-center` | `pkgs/sony-device-center.nix`, custom derivation | No Nix packaging exists upstream | `git ls-remote --tags https://github.com/marconvcm/sony-device-center.git`, put the new tag's dereferenced (`^{}`) commit in `rev` and bump `version`, then `nix build .#sony-device-center` |
| `gradient-wallpaper` | `pkgs/gradient-wallpaper.nix` | Trivial, reproducibly generated (ImageMagick) rather than checking in a binary image | Edit the colors/size in the derivation directly |
| `openwave` | flake input (`github:rikkichy/openwave`) | Upstream maintains a complete, working flake | `nix flake update openwave` |
| `opencode` | flake input (`github:sst/opencode`) | Deliberately not nixpkgs' `opencode` (lags releases); upstream's own flake handles the Bun-compile packaging | `nix flake update opencode` |
| `noctalia` | flake input (`github:noctalia-dev/noctalia`) | Provides the NixOS + Home Manager modules and the package they install (served by noctalia.cachix.org) | `nix flake update noctalia` |

## GUI apps that ended up installed without being named explicitly

A few things showed up as side effects of other choices rather than being
picked directly, listed here so they're not a surprise:

- **Nautilus** (file manager): installed for the `Mod+E` keybind, and also
  what the niri portal uses as its file picker. If you'd rather use
  something else (Thunar, pcmanfm, ...), swap the keybind and the package
  in `desktop/niri.nix` and set `programs.niri.useNautilus = false`.
- **No GNOME bloat**: `programs.niri.enable` does not pull in
  `services.desktopManager.gnome`, so none of GNOME Maps/Contacts/Tour/Yelp
  are present.

Everything else GUI (Firefox, 1Password, Vesktop, Slack, qdigidoc4, Steam, Prism
Launcher, Lunar Client, Sony Device Center, OpenWave, blueman, tuigreet)
was explicitly requested or is the direct implementation of something you
asked for by description (e.g. "a GUI or tray manager" for Bluetooth →
blueman).

## Work apps (Slack, Granola)

Slack is a plain package. Granola has no Linux build, so
`pkgs/granola.nix` repackages the pinned macOS release, following the
community [Granola-for-Linux](https://github.com/tirtha4/Granola-for-Linux)
script: the app's `app.asar` runs on nixpkgs' Electron of the same major
version, the platform string is patched (their API rejects `linux`), and
Granola's fork of `better-sqlite3-multiple-ciphers` is rebuilt for Linux
against Electron's headers. The build ends with a check that an encrypted
database and the fork's `updateHook` work. Nothing to install by hand: it's
in the workstation role and shows up as "Granola" in the launcher.

To update, bump `version` and the two hashes in `pkgs/granola.nix` (the
current version and sha512 come from Granola's update feed); if the Electron
major changes, bump `electron_44` too. Login and the app itself are untested
on real hardware; the tray icon may be missing, since the app looks for its
icons next to Electron's resources.

## Mirror repos

`modules/features/apps/mirror-repos.nix` clones the Mirror Studios repos
(deployments, infra, mono-services, falloria-network, github-actions,
proto-specs, fallernetes-operator) into `~/projects/Mirror` over SSH. A user
service does it at login and retries every minute until it works. Repos that
already exist are skipped, never touched. Run `mirror-clone` to do it by
hand; to add a repo, append it to the list in that file.

Which SSH key it uses:

- **`secrets/mirror-ssh.age` present**: that key (an agenix secret, decrypted
  to `/run/agenix/mirror-ssh` with the host's age key), so it works on a fresh
  install before 1Password is set up.
- **Otherwise**: whatever the 1Password SSH agent offers, once unlocked.

Creating the encrypted key (once, on a machine that has the repo):

```sh
ssh-keygen -t ed25519 -N "" -C mirror-clone -f /tmp/mirror-ssh   # then add /tmp/mirror-ssh.pub to GitHub
# recipients: each host's key (`sudo age-keygen -y /var/lib/agenix/host.key`), plus your own if you want to edit it later
age -r age1...laptop -r age1...desktop -o secrets/mirror-ssh.age /tmp/mirror-ssh
shred -u /tmp/mirror-ssh
git add secrets/mirror-ssh.age   # a flake only sees tracked files
```

Use a dedicated key, not your personal one: the encrypted file lives in this
public repo (and its history) for good, so anyone who ever gets a host's
`/var/lib/agenix/host.key` can decrypt it. When a host is added later, re-encrypt
with `agenix -r` after listing it in `secrets.nix`.

## Worth checking on first login

These can only be observed at runtime:

- **Niri KDL config** (`modules/features/desktop/niri.nix`): run `niri
  validate` once a session is up.
- **Hibernate** on the laptop (see "First boot").
