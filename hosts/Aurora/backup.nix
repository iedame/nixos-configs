{
  config,
  lib,
  pkgs,
  ...
}:
let
  secret = name: config.age.secrets.${name}.path;

  # What the jobs share. Each repository is its own sub-account of a
  # Hetzner Storage Box, and `repo` names it: the host alias
  # "borg-<repo>" in the SSH configuration below and the secret
  # "borg-<repo>-passphrase". Several jobs can share a repository; their
  # archives are told apart, and pruned separately, by `prefix`.
  job =
    { repo, prefix }:
    {
      repo = "ssh://borg-${repo}/./backups";
      archiveBaseName = prefix;
      doInit = false;
      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${secret "borg-${repo}-passphrase"}";
      };
      # Jobs sharing a repository wait for each other instead of failing
      extraArgs = [ "--lock-wait=3600" ];
      # An SSH configuration kept as a secret, because it holds the storage
      # box's account names: an alias "borg-<repo>" for each account, port
      # 23 and the key to use. That key is only used for backups; its public
      # half, which every account here has to accept, is:
      #   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMrQYOl914CxDHjaiYUsx9+uwYhzVBmyTMnFkZxy9YkN borg-backup@Aurora
      environment.BORG_RSH = "ssh -F ${secret "borg-ssh-config"}";
      compression = "auto,zstd";
      extraCreateArgs = [
        "--exclude-caches"
        "--stats"
      ];
      # A file that changes while it is read is a warning, not a failed
      # backup
      failOnWarnings = false;
      startAt = "daily";
      # This machine is often off at the scheduled time: run when it is next
      # on instead
      persistentTimer = true;
      prune.keep = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = 6;
      };
    };

  # For the jobs that read from the ZFS pool: it not being mounted must not
  # look like "everything was deleted"
  poolMounted = ''
    ${pkgs.util-linux}/bin/mountpoint --quiet /backup-pool/photos
    ${pkgs.util-linux}/bin/mountpoint --quiet /backup-pool/documents
  '';

  # For the jobs that back up a copy a service makes of its own data: make
  # that copy now, and wait for it, so the backup is never older than the
  # machine's last evening on
  refresh = units: "${config.systemd.package}/bin/systemctl start --wait ${units}";
in
{
  # Daily, encrypted, off-site backups with Borg. A failed run leaves a
  # failed unit, which the heartbeat (default.nix) reports. See README.md
  # here for listing and restoring.
  services.borgbackup.jobs = {
    # The Immich photo library. This repository and the next continue
    # the ones Pika Backup created, so they keep Pika's archive prefixes:
    # old and new archives then fall under the same retention rule.
    immich =
      job {
        repo = "immich";
        prefix = "14d8a7";
      }
      // {
        # The photos, and a dump of Immich's database made just before
        # (services.nix): one without the other can't be restored
        paths = [
          "/backup-pool/photos/immich"
          "${config.services.postgresqlBackup.location}/immich.sql"
        ];
        preHook = poolMounted + refresh "postgresqlBackup-immich.service";
      };

    # Documents and the home folders worth keeping
    home =
      job {
        repo = "home";
        prefix = "08333e";
      }
      // {
        preHook = poolMounted;
        paths = [
          "/backup-pool/documents"
        ]
        ++ map (folder: "/home/haoji/${folder}") [
          "Containers"
          "Desktop"
          "Documents"
          "Music"
          "Pictures"
          "Scripts"
          "Videos"
        ];
        exclude = [
          "*/.cache"
          "*/.Trash-*"
          # Paperless's files are backed up through its export instead
          # (the paperless job)
          "/backup-pool/documents/paperless"
        ];
      };

    # The small services share the "services" repository, one job each.
    #
    # Vaultwarden: the consistent copy of its database, attachments and
    # keys that its own backup job makes (services.nix, backupDir)
    vaultwarden =
      job {
        repo = "services";
        prefix = "vaultwarden";
      }
      // {
        paths = [ config.services.vaultwarden.backupDir ];
        preHook = refresh "backup-vaultwarden.service";
        # The first job of a new repository creates it
        doInit = true;
      };

    # Paperless: its export of all documents and their metadata
    # (services.nix, exporter). Paperless is stopped while that runs.
    paperless =
      job {
        repo = "services";
        prefix = "paperless";
      }
      // {
        paths = [ config.services.paperless.exporter.directory ];
        preHook = refresh "paperless-exporter.service";
      };

    # Forgejo: its dump of the repositories, LFS files, attachments and
    # settings, and a native dump of its database (services.nix)
    forgejo =
      job {
        repo = "services";
        prefix = "forgejo";
      }
      // {
        paths = [
          config.services.forgejo.dump.backupDir
          "${config.services.postgresqlBackup.location}/forgejo.sql"
        ];
        preHook = refresh "forgejo-dump.service postgresqlBackup-forgejo.service";
      };
  };

  # The vaultwarden job is the one that creates the shared repository, so
  # the others using it go after it when they start together
  systemd.services.borgbackup-job-paperless.after = [ "borgbackup-job-vaultwarden.service" ];
  systemd.services.borgbackup-job-forgejo.after = [ "borgbackup-job-vaultwarden.service" ];

  # Once a month, a consistency check of each repository (done on the
  # storage box itself, so nothing is downloaded) and of its newest
  # archive's index. It doesn't read the backed-up data back: that would
  # mean downloading all of it.
  #
  # One file is read back, though: the dump of Immich's database. Unlike a
  # photo, a damaged or cut-off dump can't be noticed by looking. The one
  # in the newest archive is downloaded and checked to end with the line
  # pg_dump writes last.
  systemd.services.borgbackup-check = {
    description = "Check the Borg repositories";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    serviceConfig.Type = "oneshot";
    script =
      lib.concatMapStrings (name: ''
        /run/current-system/sw/bin/borg-job-${name} check --lock-wait 3600 --last 1
      '') (lib.attrNames config.services.borgbackup.jobs)
      + ''
        set -o pipefail
        borg=/run/current-system/sw/bin/borg-job-immich
        archive=$($borg list --lock-wait 3600 --last 1 --format '{archive}{NL}')
        dump=${lib.removePrefix "/" config.services.postgresqlBackup.location}/immich.sql
        if ! $borg extract --lock-wait 3600 --stdout "::$archive" "$dump" \
          | tail -n 5 | grep -q 'PostgreSQL database dump complete'; then
          echo "archive $archive holds no complete dump of Immich's database ($dump)"
          exit 1
        fi
        echo "Immich database dump complete: $dump in $archive"
      '';
  };
  systemd.timers.borgbackup-check = {
    description = "Check the Borg repositories monthly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
