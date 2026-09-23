{ inputs, config, ... }:
{
  flake.nixosConfigurations.thomas-desktop = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
    };
    modules = [
      inputs.disko.nixosModules.disko
      ./disko.nix
      {
        networking.hostName = "thomas-desktop";
        hardware.facter.enable = true;
        hardware.facter.reportPath = ./facter.json;
        fileSystems."/mnt/hdd".neededForBoot = false;
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
        ];
      }
    ];
  };
}
