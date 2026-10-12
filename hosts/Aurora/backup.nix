{
  config,
  lib,
  pkgs,
  ...
}:
let
  secret = name: config.age.secrets.${name}.path;

  # What the two jobs share. They continue the repositories Pika Backup
  # created on a Hetzner Storage Box (one sub-account each), so each keeps
  # Pika's archive prefix: old and new archives then fall under the same
  # retention rule.
  job = name: prefix: {
    # "borg-<name>" is a host alias in the SSH configuration below
    repo = "ssh://borg-${name}/./backups";
    archiveBaseName = prefix;
    doInit = false;
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${secret "borg-${name}-passphrase"}";
    };
    # An SSH configuration kept as a secret, because it holds the storage
    # box's account names: an alias "borg-<name>" for each account, port
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
    # The pool not being mounted must not look like "everything was
    # deleted"
    preHook = ''
      ${pkgs.util-linux}/bin/mountpoint --quiet /backup-pool/photos
      ${pkgs.util-linux}/bin/mountpoint --quiet /backup-pool/documents
    '';
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
in
{
  # Daily, encrypted, off-site backups with Borg. A failed run leaves a
  # failed unit, which the heartbeat (default.nix) reports. See README.md
  # here for listing and restoring.
  services.borgbackup.jobs = {
    # The Immich photo library
    immich = job "immich" "14d8a7" // {
      paths = [ "/backup-pool/photos/immich" ];
    };

    # Documents and the home folders worth keeping
    home = job "home" "08333e" // {
      paths = [
        "/backup-pool/documents/haoji/onedrive"
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
      ];
    };
  };

  # Once a month, a consistency check of each repository (done on the
  # storage box itself, so nothing is downloaded) and of its newest
  # archive's index. It doesn't read the backed-up data back: that would
  # mean downloading all of it.
  systemd.services.borgbackup-check = {
    description = "Check the Borg repositories";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = lib.concatMapStrings (name: ''
      /run/current-system/sw/bin/borg-job-${name} check --lock-wait 3600 --last 1
    '') (lib.attrNames config.services.borgbackup.jobs);
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
