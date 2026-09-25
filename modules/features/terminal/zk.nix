{
  # zk: plain-markdown notes in ~/notes. Mod+N (desktop/niri.nix) opens a
  # floating terminal with a fresh note in ~/notes/inbox.
  flake.modules.homeManager.zk = {
    programs.zk = {
      enable = true;
      settings = {
        # Default notebook, used when the cwd isn't inside one (e.g. when
        # niri spawns `zk` from the Mod+N bind).
        notebook.dir = "~/notes";
        note = {
          language = "en";
          default-title = "Quick note";
          filename = "{{format-date now '%Y-%m-%d-%H%M%S'}}-{{slug title}}";
          extension = "md";
        };
        tool.editor = "nano";
        group.inbox.paths = [ "inbox" ];
        alias = {
          # zk n "some title"  -> new note in inbox
          n = "zk new inbox --title";
          # zk recent          -> last notes, newest first
          recent = "zk list --sort created- --limit 20";
        };
      };
    };

    # zk finds a notebook by its .zk directory; declare it so ~/notes needs
    # no manual `zk init`.
    home.file."notes/.zk/config.toml".text =
      "# notebook-level zk config (global settings live in ~/.config/zk)\n";
    # `zk new inbox` fails if the directory doesn't exist.
    home.file."notes/inbox/.keep".text = "";
  };
}
