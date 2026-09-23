{ inputs, config, ... }:
let
  facterReport = builtins.fromJSON (builtins.readFile ./facter.json);
  ramBytes = config.flake.lib.facter.physMemBytes facterReport;
  swapSizeGiB = config.flake.lib.facter.bytesToGiB ramBytes;
in
{
  flake.nixosConfigurations.thomas-laptop = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs swapSizeGiB;
    };
    modules = [
      inputs.disko.nixosModules.disko
      ./disko.nix
      {
        networking.hostName = "thomas-laptop";
        hardware.facter.enable = true;
        hardware.facter.reportPath = ./facter.json;
        # disko's resumeDevice=true (disko.nix) only sets boot.resumeDevice;
        # the actual kernel resume= parameter still has to be set by hand.
        boot.kernelParams = [ "resume=/dev/mapper/cryptswap" ];
      }

      config.flake.modules.nixos.core-nix
      config.flake.modules.nixos.core-locale
      config.flake.modules.nixos.core-users
      config.flake.modules.nixos.core-boot-encrypted
      config.flake.modules.nixos.core-networking
      config.flake.modules.nixos.core-home-manager
      config.flake.modules.nixos.core-zram
      config.flake.modules.nixos.security-agenix
      config.flake.modules.nixos.security-idcard
      config.flake.modules.nixos.desktop-niri
      config.flake.modules.nixos.desktop-greetd
      config.flake.modules.nixos.desktop-noctalia
      config.flake.modules.nixos.desktop-stylix
      config.flake.modules.nixos.desktop-bluetooth
      config.flake.modules.nixos.desktop-audio
      config.flake.modules.nixos.firefox
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.docker
      config.flake.modules.nixos.tailscale
      config.flake.modules.nixos.steam
      config.flake.modules.nixos.laptop-power

      {
        home-manager.users.thomas.imports = with config.flake.modules.homeManager; [
          shell
          cli-tools
          ghostty
          niri
          noctalia
          wallpaper
          firefox
          git
          gh
          ssh
          onepassword
          devenv
          zed
          zed-opencode
          discord
          minecraft
          mangohud
          sony-device-center
          openwave
          projects-dir
          laptop-touchpad
        ];
      }
    ];
  };
}
