# personal-nixos

Thomas's personal, reproducible, multi-host NixOS configuration. Flake-based,
tracks `nixos-unstable`, built with [flake-parts](https://flake.parts) using
the [Dendritic pattern](https://github.com/mightyiam/dendritic): every file
under `modules/` is itself a flake-parts module (auto-discovered via
[import-tree](https://github.com/vic/import-tree)), and each feature
contributes whatever it needs to NixOS and/or Home Manager from a single
file, instead of being split across separate `nixos/`/`home/` trees.

Hosts: `thomas-laptop`, `thomas-desktop`. User: `thomas`. Shared config by
default; host-specific things (laptop power/touchpad, dual-disk desktop
layout) only where they actually differ.

## Structure

```
flake.nix                    inputs + `import-tree ./modules`
lib/                          pure helper functions (facter report parsing)
modules/
  flake/                      flake-parts infrastructure itself
    flake-parts.nix           enables the flake.modules.* option namespace
    nixpkgs.nix, overlays.nix perSystem pkgs, allowUnfree, custom package overlay
    formatter.nix             treefmt-nix: nixfmt + statix + deadnix
    devshell.nix               `nix develop` here: tools for maintaining this repo
    hosts.nix                  brings in hosts/* (see below)
    templates.nix, install-app.nix
  features/                   the actual configuration, one aspect per file
    core/                      nix settings, locale, users, boot, networking,
                                 home-manager wiring, zram
    security/                  agenix, Estonian ID card
    desktop/                   niri, greetd, noctalia, stylix, bluetooth, audio, wallpaper
    terminal/                  ghostty, zsh+starship, CLI tools
    browser/                   firefox
    apps/                      git, gh, ssh, 1Password, devenv, docker, tailscale,
                                 discord, sony-device-center, openwave, zed/
    gaming/                    steam, minecraft
    laptop/                    power, touchpad (laptop-only)
hosts/
  thomas-laptop/               default.nix (assembles the host), disko.nix, facter.json
  thomas-desktop/               same, dual-disk (SSD + HDD)
pkgs/                          custom derivations (sony-device-center, gradient-wallpaper)
install/install.sh             interactive installer
templates/devenv-project/      `nix flake init -t` template for new projects
secrets.nix                    agenix: secret -> which keys may decrypt it
```

### How a host is assembled

Each feature file declares `flake.modules.nixos.<name>` and/or
`flake.modules.homeManager.<name>`. A host's `default.nix`
(`hosts/<name>/default.nix`) is the only place that lists which of those it
wants, e.g.:

```nix
config.flake.modules.nixos.desktop-niri
config.flake.modules.nixos.steam
# ...
home-manager.users.thomas.imports = with config.flake.modules.homeManager; [
  shell cli-tools ghostty niri zed # ...
];
```

**That list is the toggle.** A feature is "on" for a host by being listed,
"off" by not being listed — there's no separate `enable` flag to also flip.

## Adding a new host

1. `mkdir hosts/thomas-newmachine`
2. Copy `hosts/thomas-laptop/{default.nix,disko.nix}` as a starting point,
   adjust the disk layout if needed, and rename the hostname/flake output.
3. Add a placeholder `facter.json` (copy an existing one; it gets
   overwritten with the real hardware report at install time).
4. Add `../../hosts/thomas-newmachine` to `modules/flake/hosts.nix`'s
   `imports`.

That's the whole "few lines" — everything else (all the feature modules)
is already shared and just needs to be listed in the new host's
`home-manager.users.thomas.imports` / top-level `modules` list.

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
Then list `config.flake.modules.nixos.my-feature` (and/or
`homeManager.my-feature` under `home-manager.users.thomas.imports`) in
whichever host(s) should have it.

## Installing on a new machine

**This wipes the target disk(s).** Test in a VM first if you're not sure
about something (see "Testing before you commit to real hardware" below).

1. Boot the NixOS ISO on the target machine, get networking up.
2. Run (the installer ISO doesn't have `nix-command`/`flakes` enabled by
   default, hence the flag):
   ```
   nix --extra-experimental-features "nix-command flakes" run "github:UnfamousThomas/personal-nixos#install"
   ```
   (or clone the repo yourself and run `./install/install.sh`). If you're
   re-running after a fix was just pushed, add `--refresh` so it doesn't
   reuse a cached fetch of an older commit.
3. Pick the host, pick the disk(s) (the script prints `lsblk` output),
   confirm the wipe. You'll be prompted for a LUKS passphrase per encrypted
   volume as `disko-install` formats them — pick one you'll remember, TPM2
   auto-unlock gets enrolled afterwards (see "First boot" below).
4. The script generates a real hardware report via `nixos-facter` and
   installs from the flake.
5. **Before rebooting**, from the printed checkout path:
   `git add hosts/<host>/facter.json && git commit && git push` — otherwise
   the next rebuild silently falls back to the placeholder RAM figure baked
   into the repo (used for swap sizing).

Also works with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
for unattended remote installs: nixos-anywhere has its own disko and
nixos-facter integration (`--disko-mode`, `--generate-hardware-config
nixos-facter ./facter.json`), but — unlike `disko-install --disk` — it has
no disk-override flag, so set the real device path directly in
`hosts/<host>/disko.nix` before invoking it rather than relying on the
interactive prompt.

## First boot

1. **TPM2 auto-unlock**: for each LUKS volume on the host (`cryptroot`, and
   `cryptswap`/`cryptbulk` where present), enroll the TPM:
   ```
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-partlabel/<partition>
   ```
   Reboot and confirm it unlocks without a passphrase prompt. If it doesn't
   (e.g. after a firmware update invalidates the PCR measurements), you'll
   fall back to the passphrase prompt — re-enroll with the command above.
2. **Hibernate (laptop only)**: try `systemctl hibernate` and confirm it
   resumes cleanly before relying on it — disko's own swap module flags
   encrypted-swap + resume as not fully supported upstream (see comments in
   `hosts/thomas-laptop/disko.nix`); this config wires the missing
   `resume=` kernel parameter by hand, but treat it as "verify, don't
   assume."
3. **agenix key bootstrap** (the chicken-and-egg problem): a fresh host has
   no secrets yet by design (nothing in this config *requires* one at
   install time), so there's nothing to unlock on first boot. When you
   actually add a secret later:
   - Get the new host's SSH public key: `cat /etc/ssh/ssh_host_ed25519_key.pub`
   - Get your own: `cat ~/.ssh/id_ed25519.pub`
   - Add both to `secrets.nix`, list them on whichever secret(s) they
     should decrypt.
   - `agenix -e secrets/<name>.age` to write it (needs a private key for at
     least one already-listed recipient).
   - `git add secrets.nix secrets/*.age && git commit && git push`, then
     rebuild the host(s) that need it.
   - **Rekeying** (after adding a new host/key to an existing secret):
     `agenix -r` re-encrypts every secret in `secrets.nix` against the
     current key list. Commit the result.
4. **1Password**: sign in on first launch (autostarts via niri). Enable the
   SSH agent and, if your existing SSH key is Ed25519 or RSA, import it
   (Settings → Developer → SSH Agent) so `programs.ssh`'s `IdentityAgent`
   and git commit signing (both wired in `apps/onepassword.nix`) pick it
   up. Set `programs.git.settings.user.signingKey` to that key's public
   half. Turn on "Connect with 1Password in the browser" in the app so the
   Firefox extension pairs with it.
5. **Tailscale**: `sudo tailscale up`, follow the browser login link.
   MagicDNS works automatically once authenticated (systemd-resolved is
   already the resolver).
6. **SSH keys**: if you're bringing an existing key over, copy
   `~/.ssh/id_ed25519{,.pub}` into place and `chmod 600` the private key.
7. **gh auth**: `gh auth login` (interactive OAuth device flow — no secret
   needed).

## Rebuilding after changes

```
sudo nixos-rebuild switch --flake .#thomas-laptop   # or #thomas-desktop
```

Run from a checkout of this repo (`/etc/nixos` or wherever you cloned it).
`nix flake check` first is cheap and catches evaluation errors without a
full build.

## Testing before you commit to real hardware

- `nix flake check` — fast, catches evaluation/type errors in every host
  and every `flake.modules.*` entry without building anything.
- `sudo nixos-rebuild build-vm --flake .#thomas-desktop` then run the
  resulting `./result/bin/run-*-vm` — boots the config in a VM so you can
  poke at Niri/Noctalia/theming without touching real hardware. Note this
  bypasses disko/LUKS entirely (VM gets a plain virtual disk), so it won't
  catch disk-layout mistakes.
- For the disk layout itself, disko has its own VM test tooling
  (`nix run github:nix-community/disko -- --mode disko --dry-run ...` and
  disko's `disko-tests` flow) if you want to validate partitioning changes
  before running them against a real disk.

## Secrets (agenix)

See "First boot" step 3 above for the bootstrap/rekey flow. Summary of the
model: `secrets.nix` at the repo root lists, per encrypted file under
`secrets/`, which SSH public keys (user and/or host) may decrypt it.
NixOS-level secrets decrypt against the host's own SSH host key by default;
Home-Manager-level secrets (wired via `sharedModules` in
`core/home-manager.nix`) decrypt against `~/.ssh/id_ed25519`. Nothing
sensitive is ever committed in plaintext — only `.age`-encrypted files and
the public-key list in `secrets.nix` are.

## Custom / self-maintained packages

Most things come straight from nixpkgs. These don't:

| Package | Source | Why | Updating |
|---|---|---|---|
| `sony-device-center` | `pkgs/sony-device-center.nix`, custom derivation | No Nix packaging exists upstream | Bump `version`/`tag`, `hash = lib.fakeHash;`, run a build to get the real hash (or `nix-update sony-device-center`). **Currently has a placeholder hash — first build will fail until this is done.** |
| `gradient-wallpaper` | `pkgs/gradient-wallpaper.nix` | Trivial, reproducibly generated (ImageMagick) rather than checking in a binary image | Edit the colors/size in the derivation directly |
| `openwave` | flake input (`github:rikkichy/openwave`) | Upstream maintains a complete, working flake | `nix flake lock --update-input openwave` |
| `opencode` | flake input (`github:sst/opencode`) | Deliberately not nixpkgs' `opencode` (lags releases); upstream's own flake handles the Bun-compile packaging | `nix flake lock --update-input opencode` |
| `noctalia` | flake input (`github:noctalia-dev/noctalia`) | Provides the NixOS + Home Manager modules; the bare nixpkgs `noctalia-shell` package lags and has neither module | `nix flake lock --update-input noctalia` |

`sony-device-center`'s CMake install rules weren't fully verified against
the repo's actual `CMakeLists.txt` (Qt6/CMake C++ apps generally "just
work" with `stdenv.mkDerivation` + `wrapQtAppsHook`, but confirm the binary
actually lands at `$out/bin/sony-device-center` on first build and adjust
`installPhase`/`cmakeFlags` if not).

## GUI apps that ended up installed without being named explicitly

Went through this deliberately, per your "list anything I didn't ask for"
requirement:

- **Nautilus** (file manager) — pulled in automatically by
  `programs.niri.enable`'s default (`useNautilus = true`, used as the
  desktop portal's file picker). Rather than add a second GTK file manager
  on top, it's also what the `Mod+E` keybind opens. If you'd rather use
  something else (Thunar, pcmanfm, ...), say so and I'll swap the keybind
  and set `programs.niri.useNautilus = false` to drop the dependency
  entirely.
- **No GNOME bloat**: verified `programs.niri.enable` does not pull in
  `services.desktopManager.gnome`, so none of GNOME Maps/Contacts/Tour/Yelp
  are present — there was nothing to exclude via
  `environment.gnome.excludePackages`.

Everything else GUI (Firefox, 1Password, Vesktop, qdigidoc4, Steam, Prism
Launcher, Lunar Client, Sony Device Center, OpenWave, blueman, tuigreet)
was explicitly requested or is the direct implementation of something you
asked for by description (e.g. "a GUI or tray manager" for Bluetooth →
blueman).

## Verification status

`nix flake check` passes cleanly for both hosts (evaluates every
`flake.modules.*` entry, every package attribute, both `nixosConfigurations`)
as of this writing -- every package/option name in this repo actually
exists on nixos-unstable, not just "looks right." Two real bugs surfaced
and got fixed this way before ever touching real hardware: Stylix ships its
own Zed and Noctalia targets (theming both from the same `base16Scheme` as
everything else), which collided with hand-set `theme`/`buffer_font_size`
values in `zed.nix`/`noctalia.nix` -- removed in favor of letting Stylix
own those entirely, which is more consistent anyway.

What's still worth checking on first login, since it can't be evaluated,
only observed at runtime:

- **Niri KDL config** (`modules/features/desktop/niri.nix`): syntax is
  modeled closely on niri's own shipped default config, but wasn't run
  through `niri validate` (no running niri instance in this environment).
- **Noctalia wallpaper config key** (`modules/features/desktop/wallpaper.nix`):
  flagged inline — verify against docs.noctalia.dev/noctalia/theming/;
  Stylix doesn't touch wallpaper, so this one's still hand-set.
- **`sony-device-center` build**: placeholder hash (`lib.fakeHash`), and its
  CMake install rules weren't checked against the actual `CMakeLists.txt` —
  see the custom-packages table above.
- `programs.ssh.matchBlocks` (used in `apps/ssh.nix` and
  `apps/onepassword.nix`) is flagged by Home Manager as deprecated in favor
  of a new `programs.ssh.settings`-based API — still fully functional today
  (confirmed by `nix flake check` passing), left as-is rather than migrated
  to a very recently changed replacement API without being able to verify
  its exact shape first.
