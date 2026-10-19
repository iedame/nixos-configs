{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.forgejo-backup;
  forgejo = config.services.forgejo;
  staging = "/var/backup/forgejo";
  backup = config.services.restic.backups.forgejo;
  restic = lib.getExe backup.package;
  postgres = config.services.postgresql.package;
  # A scratch database for the restore test, next to the live one
  scratchDb = "forgejo_restore_test";
in
{
  # Nightly, encrypted, off-site backup of Forgejo, the same way as
  # linkding's and Vaultwarden's (restic to the private R2 backups bucket, a
  # few weeks of history), and a weekly restore test. A failure in either
  # leaves a failed unit, which the heartbeat (heartbeat.nix) reports.
  #
  # The copy is made with Forgejo stopped, a few seconds at night, so the
  # database and the repositories match: a dump of its Postgres database
  # and its state folder (repositories, LFS files, attachments and the
  # secret keys that encrypt parts of the database), without Forgejo's own
  # dumps and logs.
  #
  # `sudo restic-forgejo snapshots` lists the copies; restoring is
  # described in hosts/Ginza/README.md.
  options.custom.forgejo-backup = {
    enable = lib.mkEnableOption "a nightly off-site backup of Forgejo's database and data";
    repository = lib.mkOption {
      type = lib.types.str;
      default = "s3:https://ebce6e5a60de848f692507c157f09f80.r2.cloudflarestorage.com/oracle-nixos-backups/${lib.toLower config.networking.hostName}/forgejo";
      defaultText = lib.literalExpression ''"s3:https://<account>.r2.cloudflarestorage.com/oracle-nixos-backups/<host name>/forgejo"'';
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
    assertions = [
      {
        assertion = forgejo.database.type == "postgres";
        message = "custom.forgejo-backup dumps a Postgres database: set services.forgejo.database.type to postgres.";
      }
    ];

    services.restic.backups.forgejo = {
      inherit (cfg) repository environmentFile;
      initialize = true;
      paths = [ staging ];
      backupPrepareCommand = ''
        rm -rf ${staging}
        install -d -m 700 ${staging}
        # Started again however this ends
        trap '${config.systemd.package}/bin/systemctl start forgejo.service' EXIT
        ${config.systemd.package}/bin/systemctl stop forgejo.service
        ${pkgs.util-linux}/bin/runuser -u postgres -- ${postgres}/bin/pg_dump \
          --dbname=${forgejo.database.name} > ${staging}/forgejo.sql
        ${pkgs.rsync}/bin/rsync -a --exclude=/dump --exclude=/log --exclude=/tmp \
          ${forgejo.stateDir}/ ${staging}/state/
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

    systemd.services.forgejo-restore-test = {
      description = "Check that the newest backup of Forgejo can be restored";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      environment = {
        RESTIC_REPOSITORY = cfg.repository;
        RESTIC_CACHE_DIR = "/var/cache/forgejo-restore-test";
      };
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.git
        pkgs.jq
        pkgs.util-linux
        postgres
      ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = cfg.environmentFile;
        CacheDirectory = "forgejo-restore-test";
        CacheDirectoryMode = "0700";
        # The scratch folder: private, removed when this ends
        RuntimeDirectory = "forgejo-restore-test";
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
        copy="$RUNTIME_DIRECTORY${staging}"

        for key in secret_key internal_token oauth2_jwt_secret lfs_jwt_secret; do
          if [ ! -s "$copy/state/custom/conf/$key" ]; then
            echo "the restored copy has no $key"
            exit 1
          fi
        done

        # Every repository is intact, wikis included (owner/name.wiki.git)
        repositories=0
        while read -r repository; do
          git -c safe.directory='*' -C "$repository" fsck --no-progress --no-dangling
          case "$repository" in
            *.wiki.git) ;;
            *) repositories=$((repositories + 1)) ;;
          esac
        done < <(find "$copy/state/repositories" -mindepth 2 -maxdepth 2 -type d -name '*.git')

        # The dump loads into an empty database, which holds those
        # repositories; removed however this ends
        sql() {
          (cd / && runuser -u postgres -- psql --no-psqlrc --tuples-only --no-align --set ON_ERROR_STOP=1 "$@")
        }
        trap 'sql --dbname=postgres --command="DROP DATABASE IF EXISTS ${scratchDb}" > /dev/null' EXIT
        sql --dbname=postgres --command="DROP DATABASE IF EXISTS ${scratchDb}" > /dev/null
        sql --dbname=postgres --command="CREATE DATABASE ${scratchDb} OWNER ${forgejo.database.user}" > /dev/null
        sql --dbname=${scratchDb} --quiet < "$copy/forgejo.sql" > /dev/null
        known=$(sql --dbname=${scratchDb} --command='SELECT count(*) FROM repository')
        if [ "$known" -lt 1 ] || [ "$known" -ne "$repositories" ]; then
          echo "the database knows $known repositories, the copy has $repositories"
          exit 1
        fi

        # Every file in the repository, not only this copy's
        ${restic} check --read-data

        echo "restored the backup of $taken: $repositories repositories intact, database loaded with $known"
      '';
    };

    systemd.timers.forgejo-restore-test = {
      description = "Check weekly that the backup of Forgejo can be restored";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # After the night's backup, an hour after Vaultwarden's test
        OnCalendar = "Sun 08:30";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
    };
  };
}
