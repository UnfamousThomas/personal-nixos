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
        settings.main.leftmeta = "overload(meta, f13)";
      };
    };
  };
}
