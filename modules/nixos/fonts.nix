{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.fonts;
in
{
  options.custom.fonts = {
    enable = lib.mkEnableOption "shared fonts (Hack Nerd Font)";
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional font packages to install";
    };
  };

  # Hack (also KDE's default monospace) patched with Nerd Font icons, so the
  # terminal looks the same on every host; families: "Hack Nerd Font",
  # "Hack Nerd Font Mono" (single-width icons, for terminals), "... Propo"
  config = lib.mkIf cfg.enable {
    fonts.packages = [ pkgs.nerd-fonts.hack ] ++ cfg.extraPackages;
  };
}
