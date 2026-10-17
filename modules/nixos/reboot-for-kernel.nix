{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.reboot-for-kernel;
  notifyEnabled = config.custom.notify.enable;
  notify = lib.getExe config.custom.notify.package;
  # Written just before rebooting, read and removed once the host is back
  marker = "/var/lib/reboot-for-kernel/rebooting";
in
{
  # Reboots into a newly installed kernel. An update (self-deploy.nix, or a
  # switch by hand) activates everything else at once, but the running
  # kernel only changes at the next boot, and a host nobody restarts would
  # keep the old one, security fixes included, indefinitely.
  #
  # Once a day, at a set time, this compares the kernel, initrd and kernel
  # modules the host booted with those of the current system, and reboots
  # only if they differ. Hosts that watch each other (Narita and Nikko)
  # should be given times far enough apart that they are never down
  # together.
  #
  # With custom.notify enabled, it sends a Telegram message before
  # rebooting and another once the host is back. Uptime Kuma also sees the
  # host go down, unless a maintenance window covers the reboot time.
  options.custom.reboot-for-kernel = {
    enable = lib.mkEnableOption "rebooting into a newly installed kernel at a set time";
    at = lib.mkOption {
      type = lib.types.str;
      example = "04:40";
      description = "When to check, and reboot if needed, as a systemd calendar expression.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.reboot-for-kernel = {
      description = "Reboot if a newer kernel is installed than the one running";
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "reboot-for-kernel";
      };
      script = ''
        parts="initrd kernel kernel-modules"
        booted=$(cd /run/booted-system && readlink $parts)
        current=$(cd /run/current-system && readlink $parts)
        if [ "$booted" = "$current" ]; then
          echo "running the installed kernel; nothing to do"
          exit 0
        fi
        # Not in the middle of an update: try again tomorrow instead
        # (a oneshot unit at work is "activating", not "active")
        if [ "$(systemctl show --property=ActiveState --value self-deploy.service)" = activating ]; then
          echo "an update is running; not rebooting now"
          exit 0
        fi
        running=$(uname -r)
        installed=$(ls /run/current-system/kernel-modules/lib/modules)
        echo "running $running, installed $installed; rebooting"
        echo "$running" > ${marker}
        ${lib.optionalString notifyEnabled ''
          ${notify} "🔄 rebooting from kernel $running into $installed" ||
            echo "could not send the notification; rebooting anyway"
        ''}
        systemctl reboot
      '';
    };

    systemd.timers.reboot-for-kernel = {
      wantedBy = [ "timers.target" ];
      # Not Persistent: a check missed while the host was off isn't made up
      # at the next start, which runs the newest kernel anyway
      timerConfig.OnCalendar = cfg.at;
    };

    # After the reboot: say that the host is back, and on which kernel
    systemd.services.reboot-for-kernel-done = lib.mkIf notifyEnabled {
      description = "Report the end of a reboot into a new kernel";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = marker;
      serviceConfig = {
        Type = "oneshot";
        # The network may need a moment more after boot
        Restart = "on-failure";
        RestartSec = "30s";
      };
      # Gives up after about five minutes; the failed unit is then reported
      # by the heartbeat
      startLimitIntervalSec = 600;
      startLimitBurst = 10;
      script = ''
        before=$(cat ${marker})
        now=$(uname -r)
        if [ "$now" = "$before" ]; then
          ${notify} "⚠️ back after the reboot, but still on kernel $now"
        else
          ${notify} "✅ back, running kernel $now (was $before)"
        fi
        rm ${marker}
      '';
    };
  };
}
