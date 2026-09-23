{
  flake.modules.nixos.core-locale = {
    time.timeZone = "Europe/Tallinn";

    # Hybrid locale: English UI/collation, but Estonian date/time/measurement
    # conventions (24h clock, metric, A4 paper) -- confirmed with the user.
    i18n.defaultLocale = "en_US.UTF-8";
    # NixOS only auto-generates i18n.defaultLocale; every locale named in
    # extraLocaleSettings below has to be listed here too or it's never
    # actually built, and glibc programs (grep included) throw obscure
    # "unknown encoding"-type errors trying to use an LC_* that doesn't
    # exist on disk.
    i18n.supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "et_EE.UTF-8/UTF-8"
    ];
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "et_EE.UTF-8";
      LC_IDENTIFICATION = "et_EE.UTF-8";
      LC_MEASUREMENT = "et_EE.UTF-8";
      LC_MONETARY = "et_EE.UTF-8";
      LC_NAME = "et_EE.UTF-8";
      LC_NUMERIC = "et_EE.UTF-8";
      LC_PAPER = "et_EE.UTF-8";
      LC_TELEPHONE = "et_EE.UTF-8";
      LC_TIME = "et_EE.UTF-8";
    };

    console.keyMap = "ee";
  };
}
