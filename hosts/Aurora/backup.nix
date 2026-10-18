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

  # The monthly restore tests at the end of this file. Each restores the
  # newest archive of one job into a scratch folder, checks what came back
  # and deletes the folder again. Nothing live is written to: the only
  # things they start are, for two of them, a second Postgres that listens
  # on a socket inside the scratch folder.
  restoreTest =
    name:
    {
      packages ? [ ],
      script,
    }:
    {
      description = "Restore the newest ${name} backup into a scratch folder and check it";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.util-linux
      ]
      ++ packages;
      serviceConfig.Type = "oneshot";
      script = ''
        set -o pipefail
        borg=/run/current-system/sw/bin/borg-job-${name}
        scratch=$(mktemp -d /var/tmp/restore-test-${name}.XXXXXX)
        chmod 711 "$scratch"
        cleanup() {
          if [ -f "$scratch/pg/postmaster.pid" ]; then
            runuser -u postgres -- pg_ctl -D "$scratch/pg" -m immediate stop > /dev/null 2>&1 || true
          fi
          rm -rf "$scratch"
        }
        trap cleanup EXIT
        cd "$scratch"
        archive=$($borg list --lock-wait 3600 --glob-archives '${
          config.services.borgbackup.jobs.${name}.archiveBaseName
        }-*' --last 1 --short)
        echo "archive: $archive"
      ''
      + script;
    };
  restoreTestTimer = name: {
    description = "Test restoring the ${name} backup monthly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };

  # A second Postgres for a test to load a dump into: the same package and
  # preloaded libraries as the real one, its own empty data folder, and no
  # network port, only a socket in the scratch folder. `sql` talks to it.
  postgres = config.services.postgresql.finalPackage;
  scratchPostgres = ''
    mkdir pg sock
    chown postgres pg sock
    chmod 700 sock
    runuser -u postgres -- initdb -D "$scratch/pg" -A trust -E UTF8 > /dev/null
    runuser -u postgres -- pg_ctl -D "$scratch/pg" -w -l "$scratch/pg/server.log" \
      -o "-c listen_addresses=''' -c unix_socket_directories=$scratch/sock -c shared_preload_libraries=${
        toString (config.services.postgresql.settings.shared_preload_libraries or "")
      }" start > /dev/null
    sql() {
      runuser -u postgres -- psql --no-psqlrc --quiet --tuples-only --no-align \
        --host="$scratch/sock" --username=postgres "$@"
    }
  '';
  dumps = config.services.postgresqlBackup.location;
in
{
  # Daily, encrypted, off-site backups with Borg. A failed run leaves a
  # failed unit, which the heartbeat (default.nix) reports. See README.md
  # here for listing and restoring.
  # The storage boxes' SSH host key, so the backups never have to trust a
  # key the first time they see it. Hetzner uses this one key for every
  # storage box (checked 2026-10-17), so a wildcard covers all accounts
  # without naming them.
  programs.ssh.knownHosts.hetzner-storage-box = {
    hostNames = [ "[*.your-storagebox.de]:23" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };

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
    # Vaultwarden's job was here until it moved to Ginza (2026-10-18); its
    # old archives (prefix "vaultwarden") stay in the repository.
    #
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
        # The first job of a new repository creates it
        doInit = true;
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

  # The paperless job is the one that creates the shared repository, so
  # the other using it goes after it when they start together
  systemd.services.borgbackup-job-forgejo.after = [ "borgbackup-job-paperless.service" ];

  # Once a month, a consistency check of each repository (done on the
  # storage box itself, so nothing is downloaded) and of its newest
  # archive's index. It doesn't read the backed-up data back: that would
  # mean downloading all of it.
  #
  # One file is read back, though: the dump of Immich's database. Unlike a
  # photo, a damaged or cut-off dump can't be noticed by looking. The one
  # in the newest archive is downloaded and checked to end with pg_dump's
  # closing comment (a few lines from the end: a marker line follows it).
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
          | tail -n 20 | grep -q 'PostgreSQL database dump complete'; then
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

  # Once a month, each backup is also restored and looked at, because an
  # archive that passes the check above can still hold something useless.
  # A test fails, and the heartbeat reports it, only on a hard fault: an
  # archive that can't be extracted, a database that is damaged or won't
  # load, a file that doesn't match its recorded checksum. They don't start
  # the services on the restored data; docs/aurora-recovery.md has what was
  # tried by hand.

  # Paperless: the export's manifest can be read, and every document it
  # lists is there with the checksum the manifest records for it
  systemd.services.borgbackup-restore-test-paperless = restoreTest "paperless" {
    packages = [ pkgs.jq ];
    script = ''
      $borg extract --lock-wait 3600 "::$archive"
      copy=$scratch${config.services.paperless.exporter.directory}
      documents=$(jq '[.[] | select(.model == "documents.document")] | length' "$copy/manifest.json")
      if [ "$documents" -lt 1 ]; then
        echo "the restored export lists no documents"
        exit 1
      fi
      bad=0
      checked=0
      while IFS=$'\t' read -r file sum; do
        checked=$((checked + 1))
        if [ ! -f "$copy/$file" ] || [ "$(sha256sum "$copy/$file" | cut -d' ' -f1)" != "$sum" ]; then
          echo "file $checked of the export is missing or doesn't match its checksum"
          bad=$((bad + 1))
        fi
      done < <(jq -r '
        .[] | select(.model == "documents.document")
        | [.__exported_file_name__, .fields.checksum],
          [.__exported_archive_name__, .fields.archive_checksum]
        | select(.[0] != null and .[1] != null) | @tsv' "$copy/manifest.json")
      if [ "$bad" -gt 0 ]; then
        exit 1
      fi
      echo "restored and intact: $documents documents, $checked files match their checksums"
    '';
  };
  systemd.timers.borgbackup-restore-test-paperless = restoreTestTimer "paperless";

  # Forgejo: every repository in its dump passes git's own check, and the
  # database dump loads into an empty Postgres without an error
  systemd.services.borgbackup-restore-test-forgejo = restoreTest "forgejo" {
    packages = [
      pkgs.git
      pkgs.gnutar
      postgres
    ];
    script = ''
      $borg extract --lock-wait 3600 "::$archive"
      tar=$(find "$scratch${config.services.forgejo.dump.backupDir}" -name '*.tar' | sort | tail -n 1)
      mkdir dump
      tar -xf "$tar" -C dump
      repositories=0
      bad=0
      while IFS= read -r repository; do
        repositories=$((repositories + 1))
        if ! git -c safe.directory='*' --git-dir="$repository" fsck --no-dangling --no-progress > /dev/null 2>&1; then
          echo "repository $repositories of the dump fails git fsck"
          bad=$((bad + 1))
        fi
      done < <(find dump/repos -type d -name '*.git' -prune | sort)
      if [ "$repositories" -lt 1 ] || [ "$bad" -gt 0 ]; then
        echo "$bad of $repositories repositories are damaged or there are none"
        exit 1
      fi
    ''
    + scratchPostgres
    + ''
      # The dump re-creates the database but not its owner
      sql --dbname=postgres --command='CREATE ROLE ${config.services.forgejo.database.user} LOGIN'
      sql --dbname=postgres --set ON_ERROR_STOP=1 < "$scratch${dumps}/forgejo.sql" > /dev/null
      known=$(sql --dbname=${config.services.forgejo.database.name} --command='SELECT count(*) FROM repository')
      if [ "$known" -lt 1 ]; then
        echo "the restored database knows no repositories"
        exit 1
      fi
      echo "restored and intact: $repositories repositories on disk (wikis included), $known in the database"
    '';
  };
  systemd.timers.borgbackup-restore-test-forgejo = restoreTestTimer "forgejo";

  # Immich: the database dump loads into an empty Postgres, and 25 photos
  # picked at random from that database are in the archive with the
  # checksum Immich recorded for them. The whole library is never read
  # back: it is hundreds of GB.
  systemd.services.borgbackup-restore-test-immich = restoreTest "immich" {
    packages = [ postgres ];
    script = ''
      dump=${lib.removePrefix "/" dumps}/immich.sql
      $borg extract --lock-wait 3600 "::$archive" "$dump"
    ''
    + scratchPostgres
    + ''
      # The dump re-creates the database but not its owner. The sed is from
      # Immich's restore instructions (docs/aurora-recovery.md).
      sql --dbname=postgres --command='CREATE ROLE ${config.services.immich.database.user} LOGIN'
      sed "s/SELECT pg_catalog.set_config('search_path', ''', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" "$scratch/$dump" \
        | sql --dbname=postgres > /dev/null 2> load.log || true
      # The database still lists an extension, "vectors", that Postgres
      # here no longer has; the errors about it are expected
      if grep 'ERROR:' load.log | grep -v vectors > errors.log; then
        echo "the dump didn't load cleanly:"
        sort errors.log | uniq -c | sort -rn | head -n 10
        exit 1
      fi
      db=${config.services.immich.database.name}
      assets=$(sql --dbname="$db" --command="SELECT coalesce(to_regclass('public.asset'), to_regclass('public.assets'))")
      total=$(sql --dbname="$db" --command="SELECT count(*) FROM $assets WHERE \"deletedAt\" IS NULL")
      if [ "$total" -lt 1 ]; then
        echo "the restored database knows no photos"
        exit 1
      fi

      media=${lib.removeSuffix "/" config.services.immich.mediaLocation}
      sql --dbname="$db" --field-separator=$'\t' --command="
        SELECT encode(checksum, 'hex'), \"originalPath\" FROM $assets
        WHERE \"deletedAt\" IS NULL AND \"originalPath\" LIKE '$media/%'
        ORDER BY random() LIMIT 25" > sample.tsv
      paths=()
      sums=()
      while IFS=$'\t' read -r sum path; do
        paths+=("''${path#/}")
        sums+=("$sum")
      done < sample.tsv
      if [ "''${#paths[@]}" -lt 1 ]; then
        echo "no photo under $media to sample"
        exit 1
      fi
      mkdir photos
      (cd photos && $borg extract --lock-wait 3600 "::$archive" "''${paths[@]}") || true
      bad=0
      for i in "''${!paths[@]}"; do
        file=photos/''${paths[$i]}
        if [ ! -f "$file" ] || [ "$(sha1sum "$file" | cut -d' ' -f1)" != "''${sums[$i]}" ]; then
          echo "sampled photo $((i + 1)) is missing from the archive or doesn't match its checksum"
          bad=$((bad + 1))
        fi
      done
      if [ "$bad" -gt 0 ]; then
        exit 1
      fi
      echo "restored and intact: database with $total photos and videos; ''${#paths[@]} sampled files match their checksums"
    '';
  };
  systemd.timers.borgbackup-restore-test-immich = restoreTestTimer "immich";
}
