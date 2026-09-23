{
  # Desktop app + CLI, system-wide. polkitPolicyOwners is what makes polkit
  # (and thus the "Connect with 1Password in the browser" native messaging
  # handshake) trust this user's 1Password instance.
  flake.modules.nixos.onepassword = {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "thomas" ];
    };
  };

  # SSH agent + git commit signing through 1Password, plus autostart.
  # 1Password's SSH agent only surfaces Ed25519/RSA keys stored in a
  # 1Password vault -- import your existing key via the app's Developer
  # settings if it's one of those types; otherwise keep using it as a plain
  # file-based key (agent won't cover it, but signing can still use a
  # separate 1Password-resident key).
  flake.modules.homeManager.onepassword =
    { pkgs, ... }:
    {
      home.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
      programs.ssh.matchBlocks."*".extraOptions.IdentityAgent = "~/.1password/agent.sock";

      programs.git.settings = {
        gpg.format = "ssh";
        gpg.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign"; # documented /opt/1Password path doesn't exist on NixOS
        commit.gpgSign = true;
        # Set this to the public key of whichever key you import into
        # 1Password's SSH agent (1Password -> Settings -> Developer -> SSH
        # Agent), e.g. "ssh-ed25519 AAAA...".
        # user.signingKey = "";
      };

      myConfig.niri.extraAutostart = ''
        spawn-at-startup "1password" "--silent"
      '';
    };
}
