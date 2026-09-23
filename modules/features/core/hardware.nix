{
  # Hardware support comes from the host's nixos-facter report (set per host
  # via hardware.facter.reportPath). The committed reports start out as
  # placeholders and only become real once install/install.sh has run on the
  # machine and the result is committed.
  flake.modules.nixos.core-hardware =
    { config, lib, ... }:
    let
      isRealReport = config.hardware.facter.report ? system;
    in
    {
      # A real report sets hostPlatform itself (nixpkgs' facter/system.nix);
      # only fall back for a placeholder so evaluation still works.
      nixpkgs.hostPlatform = lib.mkIf (!isRealReport) "x86_64-linux";

      warnings = lib.optional (!isRealReport) ''
        hosts/${config.networking.hostName}/facter.json is a placeholder, not a
        real nixos-facter report: firmware, CPU microcode and initrd storage
        drivers are NOT being configured for this machine. Commit the report
        install/install.sh generated (it is left in ~/personal-nixos on the
        installed system).
      '';
    };
}
