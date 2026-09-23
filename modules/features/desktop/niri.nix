{
  flake.modules.nixos.desktop-niri = {
    programs.niri.enable = true; # wires the session, portal (xdg-desktop-portal-gnome) and a minimal Nautilus dep for the portal's file picker
  };

  # Niri itself has no Home Manager module in nixpkgs; its config is a plain
  # KDL file. `extraInput`/`extraAutostart` let host-specific feature files
  # (e.g. laptop touchpad tuning) extend this without duplicating the file.
  flake.modules.homeManager.niri =
    { lib, config, ... }:
    {
      options.myConfig.niri = {
        extraInput = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra KDL appended inside niri's `input` block.";
        };
        extraAutostart = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra `spawn-at-startup` lines.";
        };
      };

      config.xdg.configFile."niri/config.kdl".text = ''
        input {
            keyboard {
                xkb {
                    layout "ee"
                }
            }
            ${config.myConfig.niri.extraInput}
        }

        layout {
            gaps 12
            center-focused-column "never"
            default-column-width { proportion 0.5; }
            focus-ring {
                width 2
                active-color "#cba6f7"
                inactive-color "#45475a"
            }
            border {
                off
            }
        }

        prefer-no-csd

        spawn-at-startup "noctalia-shell"
        ${config.myConfig.niri.extraAutostart}

        binds {
            Mod+Return hotkey-overlay-title="Open a Terminal" { spawn "ghostty"; }
            Mod+D hotkey-overlay-title="Open Firefox" { spawn "firefox"; }
            Mod+E hotkey-overlay-title="Open File Manager" { spawn "nautilus"; }
            Mod+Z hotkey-overlay-title="Open Zed" { spawn "zeditor"; }
            Mod+C hotkey-overlay-title="Open Discord" { spawn "vesktop"; }
            Mod+P hotkey-overlay-title="Open 1Password" { spawn "1password"; }

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
            Mod+Page-Down { focus-workspace-down; }
            Mod+Page-Up   { focus-workspace-up; }

            Mod+Shift+E { quit; }
            Mod+Shift+Slash { show-hotkey-overlay; }
            Print { screenshot; }
            Mod+Print { screenshot-screen; }
        }
      '';
    };
}
