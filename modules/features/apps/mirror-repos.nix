let
  # Encrypted SSH key for cloning (README "Mirror repos"). Optional: until
  # secrets/mirror-ssh.age exists the clone falls back to the SSH agent.
  secretFile = ../../../secrets/mirror-ssh.age;
  hasSecret = builtins.pathExists secretFile;
  # Where agenix puts it at activation (age.secrets.<name> -> /run/agenix/<name>).
  keyPath = "/run/agenix/mirror-ssh";
in
{
  # Decrypted with the host's age key, so it's there on a fresh install
  # before 1Password or any user key has been set up.
  flake.modules.nixos.mirror-repos =
    { config, lib, ... }:
    {
      age.secrets = lib.mkIf hasSecret {
        mirror-ssh = {
          file = secretFile;
          owner = config.my.user;
          mode = "0400";
        };
      };
    };

  # Clones the Mirror Studios repos into ~/projects/Mirror. Only missing ones
  # are cloned, so existing checkouts (and any local work) are never touched.
  #
  # Nix can't do this at build time (it needs network and your SSH key), so it
  # is a user service that runs at login and keeps retrying until the clones
  # succeed: that covers "no network yet" and, without the encrypted key,
  # "1Password not unlocked yet". `mirror-clone` runs the same thing by hand.
  flake.modules.homeManager.mirror-repos =
    { lib, pkgs, ... }:
    let
      repos = [
        "deployments"
        "infra"
        "mono-services"
        "falloria-network"
        "github-actions"
        "proto-specs"
        "fallernetes-operator"
      ];

      mirror-clone = pkgs.writeShellApplication {
        name = "mirror-clone";
        runtimeInputs = [
          pkgs.git
          pkgs.openssh
          pkgs.coreutils
        ];
        text = ''
          dir="$HOME/projects/Mirror"
          mkdir -p "$dir"

          # First connection to github.com must not stop to ask about the host key.
          ssh_cmd="ssh -o StrictHostKeyChecking=accept-new"
          # Prefer the agenix-decrypted key (present when
          # secrets/mirror-ssh.age is in the repo); otherwise use whatever the
          # SSH agent offers.
          if [ -r ${keyPath} ]; then
            ssh_cmd="$ssh_cmd -i ${keyPath} -o IdentitiesOnly=yes"
          fi
          export GIT_SSH_COMMAND="$ssh_cmd"

          failed=0
          for repo in ${toString repos}; do
            if [ -e "$dir/$repo" ]; then
              continue
            fi
            echo "cloning $repo"
            if ! git clone "git@github.com:MirrorStudios/$repo.git" "$dir/$repo"; then
              failed=1
            fi
          done
          exit "$failed"
        '';
      };
    in
    {
      home.packages = [ mirror-clone ];

      # The same key is ssh's identity for github.com, so `git push` (and any
      # other git-over-SSH) works without 1Password. IdentitiesOnly: offer
      # only this key rather than every key the agent holds, since GitHub
      # drops the connection after a few rejected keys.
      programs.ssh.settings."github.com" = lib.mkIf hasSecret {
        IdentityFile = keyPath;
        IdentitiesOnly = true;
      };

      systemd.user.services.mirror-clone = {
        Unit.Description = "Clone missing Mirror Studios repos";
        Service = {
          Type = "oneshot";
          ExecStart = "${mirror-clone}/bin/mirror-clone";
          # Retry until the network (and the SSH key) are usable.
          Restart = "on-failure";
          RestartSec = 60;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
