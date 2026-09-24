{
  # niri has no bare-modifier bind support ("invalid key: Mod" from
  # `niri validate` -- confirmed not supported, see niri-wm/niri
  # discussion #1492). keyd is the documented workaround: a system-wide
  # key remapping daemon that can tell a tap from a hold, so held Super
  # still works as the normal modifier for every Mod+X bind, but a
  # standalone tap fires F13, which niri.nix binds to the launcher. F13 and
  # not a letter/punctuation key: niri matches binds by keysym in the active
  # layout, so a synthetic Super+/ landed on the physical key that types "-"
  # on the Estonian layout (slash is Shift+7 there) and never matched.
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
