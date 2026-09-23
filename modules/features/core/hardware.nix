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
      # Baseline, independent of the facter report: the kernel already
      # auto-detects whatever PCI/USB hardware is actually present and
      # auto-loads the matching driver (wifi chip included) -- the only
      # thing missing on a placeholder report is the firmware *files* that
      # driver needs to actually bind. Covers this without needing to know
      # the exact chip. A real facter report can still add anything more
      # specific (initrd storage drivers, microcode) on top of this.
      hardware.enableAllFirmware = lib.mkDefault true;

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
