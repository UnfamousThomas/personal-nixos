# agenix: maps each encrypted secret (secrets/<name>.age) to the list of
# age public keys allowed to decrypt it. Read only by the `agenix` CLI
# (`agenix -e`, `agenix -r`) -- never imported into the Nix module tree.
#
# The one secret is secrets/mirror-ssh.age (SSH key for cloning the Mirror
# repos, features/apps/mirror-repos.nix); it's optional, so it's only listed
# here once created, to let `agenix -e`/`agenix -r` manage it. Tailscale auth
# is an interactive `tailscale up` login, git/commit signing goes through
# 1Password, gh auth is an interactive OAuth login. agenix is wired into both
# NixOS and Home Manager (modules/features/security/agenix.nix and
# core/home-manager.nix). See README "Secrets (agenix)" and "Mirror repos".
# let
#   thomas = "age1...";          # `age-keygen -y ~/.config/age/keys.txt`
#   thomasLaptop = "age1...";    # printed by the installer, or `sudo age-keygen -y /var/lib/agenix/host.key`
#   thomasDesktop = "age1...";
# in
{
  # "example.age".publicKeys = [ thomas thomasLaptop ];
}
