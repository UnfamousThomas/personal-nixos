{
  flake.modules.nixos.firefox = {
    programs.firefox = {
      enable = true;
      policies.ExtensionSettings = {
        # uBlock Origin
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # 1Password – Password Manager (browser integration talks to the
        # desktop app via native messaging, wired up automatically by
        # programs._1password-gui; see features/apps/onepassword.nix)
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  # mimeapps.list is HM-managed (read-only): change defaults here, not via
  # app dialogs.
  flake.modules.homeManager.firefox = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "text/html" = "firefox.desktop";
      };
    };
  };
}
