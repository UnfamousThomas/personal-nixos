# agenix: maps each encrypted secret (secrets/<name>.age) to the list of
# age public keys allowed to decrypt it. Read only by the `agenix` CLI
# (`agenix -e`, `agenix -r`) -- never imported into the Nix module tree.
#
# There is one shared age key for all machines (README "Secrets"): its private
# half lives in 1Password and at /var/lib/agenix/host.key on each machine, its
# public half in secrets/age-recipient.txt (written by install/secrets-init.sh).
# So a new machine decrypts on first boot with nothing to re-encrypt.
#
# The one secret is secrets/mirror-ssh.age (SSH key for cloning the Mirror
# repos, features/apps/mirror-repos.nix).
let
  recipientFile = ./secrets/age-recipient.txt;
in
if builtins.pathExists recipientFile then
  let
    shared = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile recipientFile);
  in
  {
    "secrets/mirror-ssh.age".publicKeys = [ shared ];
  }
else
  { }
