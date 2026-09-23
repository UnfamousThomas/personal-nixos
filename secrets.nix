# agenix: maps each encrypted secret (secrets/<name>.age) to the list of
# age public keys allowed to decrypt it. Read only by the `agenix` CLI
# (`agenix -e`, `agenix -r`) -- never imported into the Nix module tree.
#
# Empty for now: this config doesn't need any secret yet (Tailscale auth is
# an interactive `tailscale up` login, git/commit signing goes through
# 1Password, gh auth is an interactive OAuth login). agenix is wired into
# both NixOS and Home Manager (modules/features/security/agenix.nix and
# core/home-manager.nix) for whenever one is. See README "Secrets (agenix)".
# let
#   thomas = "age1...";          # `age-keygen -y ~/.config/age/keys.txt`
#   thomasLaptop = "age1...";    # printed by the installer, or `sudo age-keygen -y /var/lib/agenix/host.key`
#   thomasDesktop = "age1...";
# in
{
  # "example.age".publicKeys = [ thomas thomasLaptop ];
}
