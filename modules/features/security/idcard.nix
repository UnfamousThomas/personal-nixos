{
  # Estonian ID-card (id.ee) digital signing + web authentication.
  # id.ee's own installers only target Ubuntu; this follows the community
  # NixOS-native approach documented at https://wiki.nixos.org/wiki/Web_eID
  # (esteid-pkcs11/firefox-pkcs11-loader are deprecated upstream in favour
  # of OpenSC's PKCS#11 module, per https://github.com/OpenSC/OpenSC/wiki/Estonian-eID-(EstEID)).
  #
  # Test with: launch `qdigidoc4` to confirm the reader/card is seen via
  # pcscd, then install the "Web eID" Firefox add-on and test end-to-end at
  # https://web-eid.eu/ (auth + signing demos) before trying a real relying
  # party. Known open issue to watch for: NixOS/nixpkgs#300435 (native
  # messaging host sometimes fails to connect -- retry / check
  # ~/.config/RIA/web-eid.conf logs if so).
  flake.modules.nixos.security-idcard =
    { pkgs, ... }:
    {
      services.pcscd.enable = true;

      environment.systemPackages = [
        pkgs.qdigidoc
        pkgs.web-eid-app
        pkgs.opensc
        pkgs.p11-kit
      ];

      environment.etc."pkcs11/modules/opensc-pkcs11".text = ''
        module: ${pkgs.opensc}/lib/opensc-pkcs11.so
      '';

      programs.firefox.nativeMessagingHosts.packages = [ pkgs.web-eid-app ];
      programs.firefox.policies.SecurityDevices.Add.p11-kit-proxy =
        "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
    };
}
