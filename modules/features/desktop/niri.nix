{
  flake.modules.nixos.desktop-niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true; # wires the session, portal (xdg-desktop-portal-gnome) and niri-session
      environment.systemPackages = [ pkgs.nautilus ]; # Mod+E
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
            default-column-width { proportion ${toString config.myConfig.niri.defaultColumnWidthProportion}; }
            focus-ring {
                width 2
                // Steel blue: the palette accent, softened for a window border.
                active-color "#7b9acb"
                inactive-color "#45475a"
            }
            border {
                off
            }
        }

        ${lib.optionalString (cursor != null) ''
          cursor {
              xcursor-theme "${cursor.name}"
              xcursor-size ${toString cursor.size}
          }
        ''}

        prefer-no-csd

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
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Down  { focus-window-down; }
            Mod+Up    { focus-window-up; }
            Mod+Shift+Left  { move-column-left; }
            Mod+Shift+Right { move-column-right; }
            Mod+Shift+Down  { move-window-down; }
            Mod+Shift+Up    { move-window-up; }

            Mod+Comma  { consume-window-into-column; }
            Mod+Period { expel-window-from-column; }

            Mod+F { maximize-column; }
            Mod+Shift+F { fullscreen-window; }
            Mod+Space { toggle-window-floating; }
            Mod+R { switch-preset-column-width; }
            Mod+Shift+R { reset-window-height; }

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

            Mod+Shift+E { quit; }
            // Mod+F1 works on any layout; Slash is Shift+7 on Estonian.
            Mod+F1 { show-hotkey-overlay; }
            Mod+Shift+Slash { show-hotkey-overlay; }
            Print { screenshot; }
            Mod+Print { screenshot-screen; }
        }
      '';
    };
}
