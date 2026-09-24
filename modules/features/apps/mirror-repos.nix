{
  # Clones the Mirror Studios repos into ~/projects/Mirror. Only missing ones
  # are cloned, so existing checkouts (and any local work) are never touched.
  #
  # Nix can't do this at build time (it needs network and your SSH key), so it
  # is a user service that runs at login and keeps retrying until the clones
  # succeed: that covers "no network yet" and "1Password not unlocked yet"
  # (the SSH agent only serves keys once it's unlocked). `mirror-clone` runs
  # the same thing by hand.
  flake.modules.homeManager.mirror-repos =
    { pkgs, ... }:
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
          export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"

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

      systemd.user.services.mirror-clone = {
        Unit.Description = "Clone missing Mirror Studios repos";
        Service = {
          Type = "oneshot";
          ExecStart = "${mirror-clone}/bin/mirror-clone";
          # Retry until the network and the 1Password SSH agent are usable.
          Restart = "on-failure";
          RestartSec = 60;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
