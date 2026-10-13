{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.heartbeat;
  # launchd calls a logged-in user's agents "gui/<user ID>/<label>"
  targets =
    map (label: "system/${label}") cfg.daemons
    ++ map (label: "gui/$(id -u ${config.system.primaryUser})/${label}") cfg.agents;
in
{
  # The macOS counterpart of modules/nixos/heartbeat.nix: reports this
  # Mac's health to an Uptime Kuma "push" monitor, which then notifies if
  # the reports stop coming or one says something is wrong.
  #
  # macOS has no list of failed services to consult, so "healthy" here
  # means: each launchd job named in `daemons` and `agents` is loaded, and
  # is either running or didn't end in an error the last time it ran. The agents belong to
  # system.primaryUser and only exist while that user is logged in, so
  # after a restart they count as failed until the login.
  #
  # The push URL is not in this repository: it contains the tailnet's name
  # and the monitor's token. It is read from a file, normally an agenix
  # secret (set urlFile to its path). Without that file the report is
  # skipped and nothing fails.
  options.custom.heartbeat = {
    enable = lib.mkEnableOption "reporting this Mac's health to an Uptime Kuma push monitor";
    urlFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/heartbeat-url";
      description = "File holding the monitor's push URL (a query string after it is ignored).";
    };
    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = ''
        Seconds between reports. Keep it well below the monitor's heartbeat
        interval.
      '';
    };
    daemons = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "org.nixos.nix-daemon" ];
      description = "Labels of system launchd jobs that have to be healthy.";
    };
    agents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "org.nix-community.home.linkding" ];
      description = "Labels of the primary user's launchd agents that have to be healthy.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.heartbeat = {
      path = [
        pkgs.coreutils
        pkgs.curl
        pkgs.gnugrep
        pkgs.gnused
        "/bin"
        "/usr/bin"
      ];
      script = ''
        if [ ! -r ${lib.escapeShellArg cfg.urlFile} ]; then
          exit 0
        fi
        url=$(head -n 1 ${lib.escapeShellArg cfg.urlFile})
        url=''${url%%\?*}

        failed=""
        for target in ${lib.concatMapStringsSep " " (target: ''"${target}"'') targets}; do
          if ! state=$(launchctl print "$target" 2> /dev/null); then
            failed="$failed ''${target##*/}(not-loaded)"
            continue
          fi
          # A job that is running now is healthy, whatever an earlier
          # attempt ended with: one that failed at login and was restarted
          # keeps reporting that first exit code for as long as it runs
          if printf '%s\n' "$state" | grep -q '^[[:space:]]*state = running$'; then
            continue
          fi
          # "0", another number, or "(never exited)" for one that has never
          # run
          code=$(printf '%s\n' "$state" | sed -n 's/^[[:space:]]*last exit code = \(-\{0,1\}[0-9][0-9]*\).*/\1/p' | head -n 1)
          if [ -n "$code" ] && [ "$code" != 0 ]; then
            failed="$failed ''${target##*/}"
          fi
        done

        if [ -z "$failed" ]; then
          status=up
          message=OK
        else
          status=down
          message="failed:$failed"
        fi

        # An unreachable monitor is not this Mac's failure: the missing
        # report is what raises the alarm
        curl --fail --silent --show-error --max-time 20 --get \
          --data-urlencode "status=$status" --data-urlencode "msg=$message" \
          "$url" > /dev/null || echo "$(date '+%F %T') could not reach the monitor"
      '';
      serviceConfig = {
        StartInterval = cfg.interval;
        RunAtLoad = true;
        StandardOutPath = "/var/log/heartbeat.log";
        StandardErrorPath = "/var/log/heartbeat.log";
      };
    };
  };
}
