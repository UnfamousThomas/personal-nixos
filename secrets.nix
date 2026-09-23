# agenix: maps each encrypted secret (secrets/<name>.age) to the list of
# SSH/age public keys allowed to decrypt it. Read only by the `agenix` CLI
# (`agenix -e`, `agenix -r`) -- never imported into the Nix module tree.
#
# Empty for now: this config doesn't need any secret yet (Tailscale auth is
# an interactive `tailscale up` login, git/commit signing goes through
# 1Password, gh auth is an interactive OAuth login). The scaffolding
# (agenix wired into both NixOS and Home Manager -- see
# modules/features/security/agenix.nix and core/home-manager.nix) is ready
# for whenever one is. See README "Secrets" for the full bootstrap/rekey
# flow and a worked example of adding one.
# let
#   thomas = "ssh-ed25519 AAAA...";                 # `cat ~/.ssh/id_ed25519.pub`
#   thomasLaptop = "ssh-ed25519 AAAA...";            # `cat /etc/ssh/ssh_host_ed25519_key.pub` on the host
#   thomasDesktop = "ssh-ed25519 AAAA...";
# in
{
  # "example.age".publicKeys = [ thomas thomasLaptop ];
}
