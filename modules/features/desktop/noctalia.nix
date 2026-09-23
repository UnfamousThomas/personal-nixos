{ inputs, ... }:
{
  flake.modules.nixos.desktop-noctalia = {
    imports = [ inputs.noctalia.nixosModules.default ];
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true; # NetworkManager, Bluetooth, UPower, power-profiles-daemon
    };
  };

  # Theme intentionally not set here: Stylix ships its own Noctalia target
  # that drives programs.noctalia.settings.theme from the same
  # base16Scheme as everything else (see desktop/stylix.nix) -- setting it
  # here too collided with it (conflicting definitions for `theme.source`).
  flake.modules.homeManager.noctalia = {
    imports = [ inputs.noctalia.homeModules.default ];
    programs.noctalia.enable = true;
  };
}
