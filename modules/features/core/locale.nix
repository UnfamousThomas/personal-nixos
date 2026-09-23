{
  flake.modules.nixos.core-locale = {
    time.timeZone = "Europe/Tallinn";

    # Hybrid locale: English UI/collation, but Estonian date/time/measurement
    # conventions (24h clock, metric, A4 paper) -- confirmed with the user.
    i18n.defaultLocale = "en_US.UTF-8";
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

    console.keyMap = "et";
  };
}
