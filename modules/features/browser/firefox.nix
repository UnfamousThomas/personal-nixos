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
      policies.Bookmarks = [
        {
          toplevel_name = "Bookmarks Toolbar";
          Toolbar = true;
          children = [
            {
              name = "Code";
              type = "folder";
              children = [
                {
                  name = "GitHub";
                  url = "https://github.com/MirrorStudios";
                }
                {
                  name = "Linear";
                  url = "https://linear.app";
                }
                {
                  name = "opencode";
                  url = "https://opencode.ai";
                }
              ];
            }
            {
              name = "Reading";
              type = "folder";
              children = [
                {
                  name = "Webnovel";
                  url = "https://www.webnovel.com";
                }
                {
                  name = "Patreon";
                  url = "https://www.patreon.com";
                }
                {
                  name = "ScribbleHub";
                  url = "https://www.scribblehub.com";
                }
                {
                  name = "DemonicScans";
                  url = "https://demonicscans.org";
                }
              ];
            }
            {
              name = "Learning";
              type = "folder";
              children = [
                {
                  name = "YouTube";
                  url = "https://www.youtube.com";
                }
                {
                  name = "Master.dev";
                  url = "https://master.dev";
                }
              ];
            }
            {
              name = "Gmail";
              url = "https://mail.google.com";
            }
            {
              name = "ERR";
              url = "https://www.err.ee";
            }
          ];
        }
      ];
      policies.Preferences = {
        # No "local weather" card on the new-tab page.
        "browser.newtabpage.activity-stream.showWeather" = false;
        "browser.newtabpage.activity-stream.system.showWeather" = false;
        "browser.newtabpage.activity-stream.feeds.weatherfeed" = false;
        "browser.urlbar.weather.featureGate" = false;
        # Google's the search the user actually wants in the address bar.
        "browser.search.defaultenginename" = "Google";
        "browser.search.order.1" = "Google";
        # Off: no Firefox Account/sync prompts or uploads.
        "identity.fxaccounts.enabled" = false;
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
