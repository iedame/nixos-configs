{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.disk-health;

  # `wake`: read a block from a drive that didn't answer, which spins it
  # up, and ask once more
  check = wake: ''
    problems=0

    # smartctl's exit status is a set of flags. These mean trouble:
    # 8 the drive says it is failing, 16 an attribute is past its
    # failure threshold, 128 a self-test found errors. 1, 2 and 4 mean
    # the drive couldn't be asked.
    ask() {
      status=0
      smartctl --health --attributes --log=selftest --device="$type" "$device" > /dev/null || status=$?
    }

    while read -r device type; do
      ask
      # A SATA drive on some controllers is listed as "scsi" and only
      # answers when addressed as "sat"
      if (( status & 7 )) && [ "$type" != sat ] && [ "$type" != nvme ]; then
        type=sat
        ask
      fi
      ${lib.optionalString wake ''
        if (( status & 7 )); then
          echo "$device didn't answer; waking it"
          dd if="$device" of=/dev/null bs=1M count=1 iflag=direct status=none || true
          ask
        fi
      ''}
      if (( status & (8 | 16 | 128) )); then
        echo "$device is in trouble (smartctl status $status):"
        smartctl --health --device="$type" "$device" | awk 'NF' | tail -n 3
        problems=1
      elif (( status & 7 )); then
        echo "$device: no SMART data available (smartctl status $status)"
      fi
    done < <(smartctl --scan | awk '{ print $1, $3 }')

    ${lib.optionalString cfg.zfs ''
      pools=$(zpool status -x)
      if [ "$pools" != "all pools are healthy" ] && [ "$pools" != "no pools available" ]; then
        echo "$pools"
        problems=1
      fi
    ''}
    exit "$problems"
  '';

  service = wake: {
    description = "Check the drives' health" + lib.optionalString wake ", waking sleeping drives";
    path = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.smartmontools
    ]
    ++ lib.optional cfg.zfs config.boot.zfs.package;
    serviceConfig.Type = "oneshot";
    script = check wake;
  };
in
{
  # Watches the drives, so that a failing one is noticed before it takes
  # data with it.
  #
  # smartd keeps an eye on every drive's SMART data and writes changes to
  # the journal. On its own that tells nobody, so a check runs every hour
  # and asks each drive directly; it fails, and with it shows up in the
  # heartbeat (heartbeat.nix), when a drive reports that it is failing, has
  # an attribute past its failure threshold, or has a failed self-test. On
  # a host with ZFS it also fails when a pool is anything but healthy.
  #
  # A drive that can't be asked is mentioned in the log and otherwise
  # ignored: some USB enclosures don't pass SMART through at all, and
  # others give no answer while their disk is spun down. So as not to wake
  # such a disk every hour, the hourly check leaves it alone; once a day a
  # second run wakes any drive that didn't answer and asks again.
  options.custom.disk-health = {
    enable = lib.mkEnableOption "SMART monitoring of the drives, with a failing check when one is in trouble";
    zfs = lib.mkOption {
      type = lib.types.bool;
      default = config.boot.supportedFilesystems.zfs or false;
      defaultText = lib.literalExpression "config.boot.supportedFilesystems.zfs or false";
      description = "Also fail when a ZFS pool isn't healthy.";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "How often to check, as a systemd calendar expression.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.smartd.enable = true;

    systemd.services.disk-health = service false;
    systemd.services.disk-health-full = service true;

    systemd.timers.disk-health = {
      description = "Check the drives' health regularly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        OnBootSec = "5min";
        Persistent = true;
      };
    };

    systemd.timers.disk-health-full = {
      description = "Check the drives' health daily, waking sleeping drives";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
