{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.heartbeat;
in
{
  # Reports this host's health to an Uptime Kuma "push" monitor, which then
  # notifies (by Telegram, say) in two cases: a systemd unit has failed
  # here, or the reports stop coming, because the host is down or cut off.
  #
  # Every minute it calls the monitor's push URL with status "up", or
  # "down" plus the names of the failed units. Whether silence counts as an
  # outage is the monitor's "heartbeat interval": a few minutes for a host
  # that is always on, weeks for one that is often switched off and should
  # only alert on failures.
  #
  # That interval has to be several times longer than the reporting
  # interval here. If the two are equal, every report that arrives a moment
  # late shows up as an outage followed at once by a recovery.
  #
  # The push URL is not in this repository: it contains the tailnet's name
  # and the monitor's token. It is read from a file: an agenix secret where
  # the host has agenix (set urlFile to its path), or else one put on the
  # host by hand:
  #
  #     echo 'https://<uptime-kuma>/api/push/<token>' | sudo tee /etc/heartbeat-url
  #     sudo chmod 600 /etc/heartbeat-url
  #
  # Without that file the report is skipped and nothing fails.
  options.custom.heartbeat = {
    enable = lib.mkEnableOption "reporting this host's health to an Uptime Kuma push monitor";
    urlFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/heartbeat-url";
      description = "File holding the monitor's push URL (a query string after it is ignored).";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = ''
        How often to report, as a systemd time span. Keep it well below the
        monitor's heartbeat interval.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.heartbeat = {
      description = "Report this host's health to Uptime Kuma";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.curl
        config.systemd.package
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        if [ ! -r ${lib.escapeShellArg cfg.urlFile} ]; then
          echo "no push URL in ${cfg.urlFile}; nothing to report to"
          exit 0
        fi
        url=$(head -n 1 ${lib.escapeShellArg cfg.urlFile})
        url=''${url%%\?*}

        failed=$(systemctl list-units --failed --no-legend --plain | cut -d' ' -f1 | tr '\n' ' ')
        if [ -z "$failed" ]; then
          status=up
          message=OK
        else
          status=down
          message="failed: $failed"
        fi

        # An unreachable monitor is not this host's failure: the missing
        # report is what raises the alarm
        curl --fail --silent --show-error --max-time 20 --get \
          --data-urlencode "status=$status" --data-urlencode "msg=$message" \
          "$url" > /dev/null || echo "could not reach the monitor"
      '';
    };

    systemd.timers.heartbeat = {
      description = "Report this host's health to Uptime Kuma, regularly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        # The default of a minute would let reports drift by as much as
        # they are apart
        AccuracySec = "5s";
      };
    };
  };
}
