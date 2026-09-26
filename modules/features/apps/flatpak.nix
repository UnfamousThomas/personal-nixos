{
  # Flatpak, with Stremio as the one declared app. Stremio is on Flathub
  # rather than nixpkgs' `stremio` because the latter depends on the EOL
  # Qt5 WebEngine and is flagged insecure.
  #
  # There's no declarative flatpak module in nixpkgs (that would be the
  # nix-flatpak flake), so a oneshot unit adds the Flathub remote and
  # installs anything listed below. It only adds -- removing an app from
  # the list won't uninstall it (`flatpak uninstall <id>`).
  flake.modules.nixos.flatpak =
    { lib, pkgs, ... }:
    let
      apps = [ "com.stremio.Stremio" ];
    in
    {
      services.flatpak.enable = true;

      systemd.services.flatpak-setup = {
        description = "Add the Flathub remote and install declared Flatpak apps";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "flatpak-system-helper.service"
        ];
        path = [ pkgs.flatpak ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Offline boots shouldn't leave a failed unit behind; it retries
          # on the next boot or `systemctl restart flatpak-setup`.
          SuccessExitStatus = "0 1";
        };
        script = ''
          flatpak remote-add --system --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
          flatpak install --system --noninteractive --or-update flathub ${lib.escapeShellArgs apps}
        '';
      };
    };
}
