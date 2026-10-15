{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.linkding-backup;
  data = config.services.linkding.dataDir;
  staging = "/var/backup/linkding";
  backup = config.services.restic.backups.linkding;
  restic = lib.getExe backup.package;
  sqlite = lib.getExe pkgs.sqlite;
in
{
  # Nightly, encrypted, off-site backup of linkding: the bookmarks and tags
  # exist only in its database. The same pattern as Uptime Kuma's backup
  # (uptime-kuma-backup.nix): restic to the private R2 backups bucket, a
  # few weeks of history, and a weekly restore test that reads the newest
  # copy back into a scratch folder and inspects it. A failure in either
  # leaves a failed unit, which the heartbeat (heartbeat.nix) reports.
  #
  # `sudo restic-linkding snapshots` lists the copies; restoring is
  # described in hosts/Ginza/README.md.
  options.custom.linkding-backup = {
    enable = lib.mkEnableOption "a nightly off-site backup of linkding's data";
    repository = lib.mkOption {
      type = lib.types.str;
      default = "s3:https://ebce6e5a60de848f692507c157f09f80.r2.cloudflarestorage.com/oracle-nixos-backups/${lib.toLower config.networking.hostName}/linkding";
      defaultText = lib.literalExpression ''"s3:https://<account>.r2.cloudflarestorage.com/oracle-nixos-backups/<host name>/linkding"'';
      description = "The restic repository: the host's folder in the backups bucket, and in it one per service.";
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
    services.restic.backups.linkding = {
      inherit (cfg) repository environmentFile;
      initialize = true;
      paths = [ staging ];
      # SQLite's own backup command gives a consistent copy of the database
      # while linkding keeps running. The secret key keeps logins valid
      # after a restore; favicons, previews and archived pages are files.
      backupPrepareCommand = ''
        rm -rf ${staging}
        install -d -m 700 ${staging}
        ${sqlite} ${data}/db.sqlite3 ".backup '${staging}/db.sqlite3'"
        cp -a ${data}/secretkey.txt ${data}/favicons ${data}/previews ${data}/assets ${staging}/
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

    systemd.services.linkding-restore-test = {
      description = "Check that the newest backup of linkding can be restored";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        RESTIC_REPOSITORY = cfg.repository;
        RESTIC_CACHE_DIR = "/var/cache/linkding-restore-test";
      };
      path = [
        pkgs.coreutils
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = cfg.environmentFile;
        CacheDirectory = "linkding-restore-test";
        CacheDirectoryMode = "0700";
        # The scratch folder: in memory, private, removed when this ends
        RuntimeDirectory = "linkding-restore-test";
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
        db="$RUNTIME_DIRECTORY${staging}/db.sqlite3"

        result=$(${sqlite} "$db" "pragma integrity_check;")
        if [ "$result" != ok ]; then
          echo "the restored database is damaged: $result"
          exit 1
        fi
        bookmarks=$(${sqlite} "$db" "select count(*) from bookmarks_bookmark;")
        if [ "$bookmarks" -lt 1 ]; then
          echo "the restored database has no bookmarks"
          exit 1
        fi
        if [ ! -s "$RUNTIME_DIRECTORY${staging}/secretkey.txt" ]; then
          echo "the restored copy has no secret key"
          exit 1
        fi

        # Every file in the repository, not only this copy's
        ${restic} check --read-data

        echo "restored the backup of $taken: database intact, $bookmarks bookmarks"
      '';
    };

    systemd.timers.linkding-restore-test = {
      description = "Check weekly that the backup of linkding can be restored";
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
