{
  flake.modules.homeManager.wallpaper =
    { pkgs, ... }:
    {
      home.file.".local/share/wallpapers/gradient-mocha.png".source =
        "${pkgs.gradient-wallpaper}/share/wallpapers/gradient-mocha.png";

      # NOTE: Noctalia's wallpaper config schema wasn't in scope of what was
      # verified for this repo -- double check this key against
      # https://docs.noctalia.dev/noctalia/theming/ on first login. If it
      # differs, set the wallpaper once via the Noctalia settings UI
      # instead; it persists in ~/.config/noctalia/config.toml, which Home
      # Manager doesn't manage.
      programs.noctalia.settings.wallpaper.path =
        "${pkgs.gradient-wallpaper}/share/wallpapers/gradient-mocha.png";
    };
}
