{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.flatpak;
in
{
  # Flatpak for the apps installed without going through this config (from
  # Discover, say), kept up to date by itself. Apps are installed
  # system-wide, which is what Discover does here.
  options.custom.flatpak = {
    enable = lib.mkEnableOption "Flatpak with Flathub and weekly automatic updates";
    updateAt = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "When to update the installed Flatpaks (systemd calendar event); a missed run is made up at the next boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    # Flathub has to be added once per machine, which this does. The network
    # is often not up yet when it runs at boot, so it does nothing once
    # Flathub is there and otherwise retries every minute.
    systemd.services.flatpak-add-flathub = {
      description = "Add the Flathub repository to Flatpak";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "1min";
      };
      script = ''
        if flatpak remotes --system --columns=name | grep -qx flathub; then
          exit 0
        fi
        flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      '';
    };

    # The update: apps and runtimes, then the runtimes no app needs any
    # more. An app that is open keeps running the old version until it is
    # next started. Without a network it retries for about an hour before
    # it counts as failed, which the heartbeat reports.
    systemd.services.flatpak-update = {
      description = "Update the installed Flatpaks";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "flatpak-add-flathub.service"
      ];
      path = [ pkgs.flatpak ];
      startLimitBurst = 6;
      startLimitIntervalSec = 2 * 60 * 60;
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "10min";
      };
      script = ''
        flatpak update --system --noninteractive
        flatpak uninstall --system --unused --noninteractive
      '';
    };
    systemd.timers.flatpak-update = {
      description = "Update the installed Flatpaks regularly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.updateAt;
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    # Discover's update notifier would only announce what the update above
    # does anyway (on NixOS, Discover can update nothing but Flatpaks). This
    # entry, earlier in the autostart search path than Discover's own, keeps
    # it from starting with the session. Discover itself stays.
    environment.etc."xdg/autostart/org.kde.discover.notifier.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
