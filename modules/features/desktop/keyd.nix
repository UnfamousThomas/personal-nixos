{
  # niri has no bare-modifier bind support ("invalid key: Mod" from
  # `niri validate` -- confirmed not supported, see niri-wm/niri
  # discussion #1492). keyd is the documented workaround: a system-wide
  # key remapping daemon that can tell a tap from a hold, so held Super
  # still works as the normal modifier for every Mod+X bind, but a
  # standalone tap fires a synthetic Super+/ keypress -- which niri.nix's
  # existing Mod+Slash bind already opens the launcher on.
  flake.modules.nixos.keyd = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings.main.leftmeta = "overload(meta, macro(leftmeta+slash))";
      };
    };
  };
}
