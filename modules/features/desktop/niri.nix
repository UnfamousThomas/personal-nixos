{
  flake.modules.nixos.desktop-niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true; # wires the session, portal (xdg-desktop-portal-gnome) and niri-session
      environment.systemPackages = [
        pkgs.nautilus # Mod+E
        pkgs.playerctl # XF86AudioPlay/Next/Prev binds
        # niri integrates xwayland-satellite (>= 0.7) automatically when it's
        # in PATH: it exports $DISPLAY and spawns it on demand for X11-only
        # apps like Steam ("Unable to open a connection to X" otherwise).
        pkgs.xwayland-satellite
      ];
    };

  # Niri itself has no Home Manager module in nixpkgs; its config is a plain
  # KDL file. myConfig.niri.{extraInput,extraAutostart} (declared in
  # core/options.nix) let other features extend it without duplicating it.
  flake.modules.homeManager.niri =
    { lib, config, ... }:
    let
      # Cursor theme for niri and everything it spawns, from stylix.cursor.
      cursor = config.stylix.cursor or null;
    in
    {
      # A launcher entry for the hotkey overlay (also on Mod+F1), so the
      # shortcuts can be found by searching for them.
      xdg.desktopEntries.keyboard-shortcuts = {
        name = "Keyboard Shortcuts";
        genericName = "Hotkey Overlay";
        comment = "Show the list of keyboard shortcuts";
        exec = "niri msg action show-hotkey-overlay";
        icon = "input-keyboard";
        categories = [ "Utility" ];
        terminal = false;
      };

      xdg.configFile."niri/config.kdl".text = ''
        input {
            keyboard {
                xkb {
                    layout "ee"
                    // Plain "ee" makes ~ (and other diacritic-composing
                    // keys) a dead key needing a second press (e.g.
                    // Space) to produce the bare character -- useful for
                    // typing Estonian prose, annoying for shell/terminal
                    // use. nodeadkeys trades that away for direct output.
                    variant "nodeadkeys"
                }
            }
            ${config.myConfig.niri.extraInput}
        }

        layout {
            gaps 12
            center-focused-column "never"
            // Matches Catppuccin Mocha base. niri's default background is
            // #404040 gray and shows behind (and before) Noctalia's wallpaper
            // layer: on a slow/failed wallpaper load the whole desktop used
            // to flash/flip gray.
            background-color "#1e1e2e"
            default-column-width { proportion ${toString config.myConfig.niri.defaultColumnWidthProportion}; }
            focus-ring {
                // 1px, active-only steel blue: the gray ring was the
                // focus-ring's inactive-color on the other monitor, so
                // drop it to transparent and keep the accent subtle.
                width 1
                active-color "#7b9acb"
                inactive-color "#45475a00"
            }
            border {
                off
            }
        }

        // Steam's UI renders wider than its content needs, so at the shared
        // 0.5 default width it squeezes a side-by-side app (Discord's server
        // rail) off its monitor. Open it a bit narrower instead.
        window-rule {
            match app-id=r#"^steam$"#
            default-column-width { proportion 0.4; }
        }

        // Steam's friend-in-game notifications are X11 toast popups (titles
        // notificationtoasts_N_desktop) that niri maps as plain floating
        // windows in the center of the screen. Pin them to the bottom-right
        // and keep them from stealing focus from whatever's in front.
        window-rule {
            match app-id=r#"^steam$"# title=r#"^notificationtoasts_\d+_desktop$"#
            default-floating-position x=10 y=10 relative-to="bottom-right"
            open-focused false
        }

        // Discord collapses its friends/channel rail itself once the window
        // is narrow enough, so pin the default width low enough (fixed
        // pixels, not a proportion -- breakpoints key on width) to trigger
        // that on a 1920px monitor. Mod+R (switch-preset-column-width) then
        // widens it back out when the rail is wanted.
        window-rule {
            match app-id=r#"^(vesktop|discord)$"#
            default-column-width { fixed 720; }
        }

        ${lib.optionalString (cursor != null) ''
          cursor {
              xcursor-theme "${cursor.name}"
              xcursor-size ${toString cursor.size}
          }
        ''}

        prefer-no-csd

        ${config.myConfig.niri.extraOutput}

        ${config.myConfig.niri.extraAutostart}

        binds {
            Mod+Return hotkey-overlay-title="Open a Terminal" { spawn "ghostty"; }
            Mod+D hotkey-overlay-title="Open Firefox" { spawn "firefox"; }
            Mod+E hotkey-overlay-title="Open File Manager" { spawn "nautilus"; }
            Mod+Z hotkey-overlay-title="Open Zed" { spawn "zeditor"; }
            Mod+C hotkey-overlay-title="Open Discord" { spawn "vesktop"; }
            Mod+P hotkey-overlay-title="Open 1Password" { spawn "1password"; }
            // Tapping Super sends the F13 keycode (keyd.nix). niri binds by
            // keysym and xkeyboard-config maps that keycode to XF86Tools.
            // Mod+A opens the launcher too, without keyd.
            XF86Tools hotkey-overlay-title="Open Launcher (Super tap)" { spawn-sh "noctalia msg panel-toggle launcher"; }
            Mod+A { spawn-sh "noctalia msg panel-toggle launcher"; }

            Mod+Q { close-window; }
            Mod+Left  hotkey-overlay-title="Focus column left"  { focus-column-left; }
            Mod+Right hotkey-overlay-title="Focus column right" { focus-column-right; }
            Mod+Down  hotkey-overlay-title="Focus window down"  { focus-window-down; }
            Mod+Up    hotkey-overlay-title="Focus window up"    { focus-window-up; }
            Mod+Shift+Left  hotkey-overlay-title="Move column left"  { move-column-left; }
            Mod+Shift+Right hotkey-overlay-title="Move column right" { move-column-right; }
            Mod+Shift+Down  hotkey-overlay-title="Move window down"  { move-window-down; }
            Mod+Shift+Up    hotkey-overlay-title="Move window up"    { move-window-up; }
            Mod+Ctrl+Left  hotkey-overlay-title="Focus monitor left"  { focus-monitor-left; }
            Mod+Ctrl+Right hotkey-overlay-title="Focus monitor right" { focus-monitor-right; }
            Mod+Ctrl+Shift+Left  hotkey-overlay-title="Push column to left monitor"  { move-column-to-monitor-left; }
            Mod+Ctrl+Shift+Right hotkey-overlay-title="Push column to right monitor" { move-column-to-monitor-right; }

            Mod+Comma  hotkey-overlay-title="Stack window into column"  { consume-window-into-column; }
            Mod+Period hotkey-overlay-title="Unstack window from column" { expel-window-from-column; }

            Mod+F hotkey-overlay-title="Maximize column" { maximize-column; }
            Mod+Shift+F hotkey-overlay-title="Fullscreen window" { fullscreen-window; }
            Mod+Space hotkey-overlay-title="Toggle floating" { toggle-window-floating; }
            Mod+R hotkey-overlay-title="Cycle column width" { switch-preset-column-width; }
            Mod+Shift+R hotkey-overlay-title="Reset window height" { reset-window-height; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }
            Mod+Shift+1 { move-column-to-workspace 1; }
            Mod+Shift+2 { move-column-to-workspace 2; }
            Mod+Shift+3 { move-column-to-workspace 3; }
            Mod+Shift+4 { move-column-to-workspace 4; }
            Mod+Shift+5 { move-column-to-workspace 5; }
            Mod+Page_Down { focus-workspace-down; }
            Mod+Page_Up   { focus-workspace-up; }
            // Mod+Tab is the Windows-style app switcher. Noctalia's window
            // switcher shows a centered grid of the windows on the current
            // screen (Tab/arrows/Enter to pick). niri's own overview
            // (toggle-overview, also on the top-left hot corner) zooms out over
            // every workspace, which reads as a desktop grid when workspaces
            // only hold one window each -- so this is the better daily switch.
            Mod+Tab hotkey-overlay-title="Switch window" { spawn-sh "noctalia msg window-switcher"; }
            // "Scroll" between windows by holding Mod and wheeling. Cycles within
            // the current workspace only (down-or-top wraps around); it never
            // switches workspaces, so a single-window workspace simply holds
            // still. Direction follows niri's natural-scroll setting.
            Mod+WheelScrollDown { focus-window-down-or-top; }
            Mod+WheelScrollUp   { focus-window-up-or-bottom; }

            Mod+Shift+E { quit; }
            // Mod+F1 works on any layout; Slash is Shift+7 on Estonian.
            Mod+F1 { show-hotkey-overlay; }
            Mod+Shift+Slash { show-hotkey-overlay; }
            Print { screenshot; }
            Mod+Print { screenshot-screen; }

            // niri has no built-in media-key handling, so without these binds
            // the keyboard's volume/play buttons would do nothing. wpctl
            // drives PipeWire volume; playerctl drives any MPRIS player
            // (Spotify, Firefox, Discord ...). Volume steps as percentages so
            // they scale with the current sink's range.
            XF86AudioRaiseVolume hotkey-overlay-title="Volume up" { spawn "wpctl" "set-volume" "--limit" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"; }
            XF86AudioLowerVolume hotkey-overlay-title="Volume down" { spawn "wpctl" "set-volume" "--limit" "1.0" "@DEFAULT_AUDIO_SINK@" "5%-"; }
            XF86AudioMute        hotkey-overlay-title="Mute" { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
            XF86AudioMicMute     hotkey-overlay-title="Mute microphone" { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
            XF86AudioPlay hotkey-overlay-title="Play/Pause" { spawn "playerctl" "play-pause"; }
            XF86AudioNext hotkey-overlay-title="Next track" { spawn "playerctl" "next"; }
            XF86AudioPrev hotkey-overlay-title="Previous track" { spawn "playerctl" "previous"; }
            XF86AudioStop hotkey-overlay-title="Stop" { spawn "playerctl" "stop"; }
        }
      '';
    };
}
