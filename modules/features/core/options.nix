{
  # Per-machine facts other modules read. A host sets (or mkForces) them in
  # its own module.
  flake.modules.nixos.core-options =
    { lib, ... }:
    {
      options.my.user = lib.mkOption {
        type = lib.types.str;
        default = "thomaspalts";
        description = "Name of the single interactive user this machine is set up for.";
      };
    };

  # Hooks that Home Manager features contribute to without importing the
  # feature that consumes them (e.g. 1Password autostarting through niri).
  # Declared here, and added to every HM user via sharedModules in
  # core-home-manager, so setting them never depends on niri being imported.
  flake.modules.homeManager.core-options =
    { lib, ... }:
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
        # 0.5 means two columns fill the screen -- fine on a laptop, but
        # cramped on a wider desktop monitor where more should fit at
        # once. Per-host since it depends on actual screen width, not
        # something a single shared default can get right everywhere.
        defaultColumnWidthProportion = lib.mkOption {
          type = lib.types.float;
          default = 0.5;
          description = "Proportion of output width niri's default column width takes up.";
        };
      };
    };
}
