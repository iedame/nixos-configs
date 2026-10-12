{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.uptime-kuma-backup;
  # /var/lib/uptime-kuma, without the trailing slash of the setting
  data = lib.removeSuffix "/" config.services.uptime-kuma.settings.DATA_DIR;
  staging = "/var/backup/uptime-kuma";
  backup = config.services.restic.backups.uptime-kuma;
  restic = lib.getExe backup.package;
  sqlite = lib.getExe pkgs.sqlite;
in
{
  # Nightly, encrypted, off-site backup of Uptime Kuma: its monitors,
  # notification settings and history are made in its web interface and
  # exist only in its database, which this repository can't rebuild.
  #
  # restic uploads to a private Cloudflare R2 bucket and keeps a few weeks
  # of history. A backup that fails leaves a failed unit behind, which the
  # heartbeat (heartbeat.nix) reports.
  #
  # A backup is only known to work once it has been restored, so once a
  # week the newest copy is restored into a scratch folder and inspected,
  # and every file in the repository is read back and verified. That test
  # only reads: it touches neither the running Uptime Kuma nor the copies
  # in the bucket, and it fails, and so alerts, in the same way.
  #
  # `sudo restic-uptime-kuma snapshots` lists the copies; restoring is
  # described in hosts/Narita/README.md.
  options.custom.uptime-kuma-backup = {
    enable = lib.mkEnableOption "a nightly off-site backup of Uptime Kuma's data";
    repository = lib.mkOption {
      type = lib.types.str;
      default = "s3:https://ebce6e5a60de848f692507c157f09f80.r2.cloudflarestorage.com/oracle-nixos-backups/${lib.toLower config.networking.hostName}";
      defaultText = lib.literalExpression ''"s3:https://<account>.r2.cloudflarestorage.com/oracle-nixos-backups/<host name>"'';
      description = "The restic repository: one folder per host in the backups bucket.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        File setting AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (an R2
        token that can read and write the bucket) and RESTIC_PASSWORD (the
        key the backup is encrypted with).
      '';
    };
    maxAgeHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 48;
      description = "The weekly restore test fails if the newest backup is older than this.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups.uptime-kuma = {
      inherit (cfg) repository environmentFile;
      initialize = true;
      paths = [ staging ];
      # Copying the database file while Uptime Kuma writes to it can give
      # a corrupt copy; SQLite's own backup command gives a consistent one
      # without stopping the service
      backupPrepareCommand = ''
        rm -rf ${staging}
        install -d -m 700 ${staging}
        ${sqlite} ${data}/kuma.db ".backup '${staging}/kuma.db'"
        cp -a ${data}/db-config.json ${data}/upload ${staging}/
      '';
      backupCleanupCommand = "rm -rf ${staging}";
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      # Verifies the repository's structure after every backup
      runCheck = true;
      timerConfig = {
        OnCalendar = "03:30";
        RandomizedDelaySec = "30min";
        # Catches up after a night the host was down
        Persistent = true;
      };
    };

    systemd.services.uptime-kuma-restore-test = {
      description = "Check that the newest backup of Uptime Kuma can be restored";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        RESTIC_REPOSITORY = cfg.repository;
        RESTIC_CACHE_DIR = "/var/cache/uptime-kuma-restore-test";
      };
      path = [
        pkgs.coreutils
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = cfg.environmentFile;
        CacheDirectory = "uptime-kuma-restore-test";
        CacheDirectoryMode = "0700";
        # The scratch folder: in memory, private, removed when this ends
        RuntimeDirectory = "uptime-kuma-restore-test";
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        set -eu

        # The nightly backup may have stopped without anything failing
        taken=$(${restic} snapshots --latest 1 --json | jq -r 'max_by(.time).time')
        age=$(( $(date +%s) - $(date -d "$taken" +%s) ))
        if [ "$age" -gt ${toString (cfg.maxAgeHours * 3600)} ]; then
          echo "the newest backup is from $taken: older than ${toString cfg.maxAgeHours} hours"
          exit 1
        fi

        ${restic} restore latest --target "$RUNTIME_DIRECTORY"
        db="$RUNTIME_DIRECTORY${staging}/kuma.db"

        result=$(${sqlite} "$db" "pragma integrity_check;")
        if [ "$result" != ok ]; then
          echo "the restored database is damaged: $result"
          exit 1
        fi
        monitors=$(${sqlite} "$db" "select count(*) from monitor;")
        if [ "$monitors" -lt 1 ]; then
          echo "the restored database has no monitors"
          exit 1
        fi

        # Every file in the repository, not only this copy's
        ${restic} check --read-data

        echo "restored the backup of $taken: database intact, $monitors monitors"
      '';
    };

    systemd.timers.uptime-kuma-restore-test = {
      description = "Check weekly that the backup of Uptime Kuma can be restored";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # After the night's backup and the weekly store clean-up
        OnCalendar = "Sun 06:30";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
    };
  };
}
