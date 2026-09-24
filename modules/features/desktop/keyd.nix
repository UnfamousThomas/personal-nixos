{
  # niri has no bare-modifier bind ("invalid key: Mod" from `niri validate`,
  # see niri-wm/niri discussion #1492). keyd is the documented workaround: a
  # system-wide key remapping daemon that can tell a tap from a hold, so held
  # Super is the normal modifier for every Mod+X bind, and a standalone tap
  # fires the F13 keycode, which niri.nix binds to the launcher. F13 is layout-independent; niri matches binds by keysym in the
  # active layout, so a letter or punctuation key would move around with it.
  flake.modules.nixos.keyd = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings = {
          # keyd re-emits every Caps Lock press as an immediate
          # press+release macro, so xkb's "unlock takes effect on key
          # release" behavior never delays the toggle (the classic
          # "CAps LOck" Wayland lag). macro_timeout stops a held Caps
          # Lock from re-firing the macro, so only real taps toggle.
          global.macro_timeout = "600000";
          main = {
            leftmeta = "overload(meta, f13)";
            capslock = "macro(capslock)";
          };
        };
      };
    };
  };
}
