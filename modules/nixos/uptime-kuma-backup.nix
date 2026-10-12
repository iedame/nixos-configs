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
        ${lib.getExe pkgs.sqlite} ${data}/kuma.db ".backup '${staging}/kuma.db'"
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
  };
}
