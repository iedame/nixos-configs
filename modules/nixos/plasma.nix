{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.plasma;
in
{
  options.custom.plasma = {
    enable = lib.mkEnableOption "the KDE Plasma 6 desktop (SDDM, PipeWire audio)";
    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      example = "br";
      description = "XKB keyboard layout, also used by the Wayland session and SDDM.";
    };
    keyboardVariant = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "intl";
      description = "XKB variant of the keyboard layout; empty for the layout's default.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable the X11 windowing system.
    # You can disable this if you're only using the Wayland session.
    services.xserver.enable = true;

    # Enable the KDE Plasma Desktop Environment.
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = cfg.keyboardLayout;
      variant = cfg.keyboardVariant;
    };

    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
