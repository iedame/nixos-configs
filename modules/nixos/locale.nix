{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.locale;

  # Categories that follow the regional locale (dates, numbers, units, ...);
  # messages and everything else stay in defaultLocale
  regionalCategories = [
    "LC_ADDRESS"
    "LC_IDENTIFICATION"
    "LC_MEASUREMENT"
    "LC_MONETARY"
    "LC_NAME"
    "LC_NUMERIC"
    "LC_PAPER"
    "LC_TELEPHONE"
    "LC_TIME"
  ];
in
{
  options.custom.locale = {
    enable = lib.mkEnableOption "time zone and locale settings";
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "America/Sao_Paulo";
      description = "System time zone";
    };
    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Locale for messages and anything not covered by regionalLocale";
    };
    regionalLocale = lib.mkOption {
      type = lib.types.str;
      default = "pt_BR.UTF-8";
      description = "Locale for dates, numbers, currency, units, addresses, etc.";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;
    i18n.extraLocaleSettings = lib.genAttrs regionalCategories (_: cfg.regionalLocale);
  };
}
