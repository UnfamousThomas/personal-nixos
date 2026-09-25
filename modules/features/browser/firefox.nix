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
        # Stylus (user styles live in the extension's own storage, so the
        # styles themselves can't be declared here)
        "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
          installation_mode = "force_installed";
        };
      };
      # Firefox's Bookmarks policy is a flat list (Title/URL/Placement/Folder),
      # not Chrome's nested name/url/children format.
      policies.Bookmarks =
        let
          bm =
            folder: title: url:
            {
              Title = title;
              URL = url;
              Placement = "toolbar";
            }
            // (if folder == null then { } else { Folder = folder; });
        in
        [
          (bm "Code" "GitHub" "https://github.com/MirrorStudios")
          (bm "Code" "Linear" "https://linear.app")
          (bm "Code" "Greptile" "https://app.greptile.com")
          (bm "Code" "Claude" "https://claude.ai")
          (bm "Reading" "Webnovel" "https://www.webnovel.com")
          (bm "Reading" "Patreon" "https://www.patreon.com")
          (bm "Reading" "ScribbleHub" "https://www.scribblehub.com")
          (bm "Reading" "DemonicScans" "https://demonicscans.org")
          (bm "Learning" "Master.dev" "https://master.dev")
          (bm "Random" "X" "https://x.com")
          (bm "Random" "YouTube" "https://www.youtube.com")
          (bm null "Gmail" "https://mail.google.com")
          (bm null "ERR" "https://www.err.ee")
        ];
      policies.Preferences = {
        # Toolbar is otherwise only shown on the new-tab page.
        "browser.toolbars.bookmarks.visibility" = "always";
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
