{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable Syncthing
  services.syncthing = {
    enable = true;
  };

  # Immich moved to Nara (2026-10-19). What stays here is its machine
  # learning, which Nara uses, and, until the mirror on the external pool
  # replaces the Borg backup, the database and the old media folder.
  services.immich = {
    enable = true;
    mediaLocation = "/backup-pool/photos/immich/";
    # Only the server used Redis
    redis.enable = false;
    machine-learning.environment = {
      HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      XDG_CACHE_HOME = "/var/cache/immich";
      # Serves Nara's Immich, over Tailscale (hosts/Nara/immich.nix). It
      # has no login of its own: the firewall opens its port on tailscale0
      # only (below), and the tailnet's access rules decide who reaches it.
      IMMICH_HOST = lib.mkForce "0.0.0.0";
      # Idle connections stay open longer than Nara's client keeps them
      # (about 4 s). With the default 2 s, a request sent on a connection
      # Aurora was just closing failed as "other side closed", more often
      # with the ~230 ms between Helsinki and Aurora.
      MACHINE_LEARNING_HTTP_KEEPALIVE_TIMEOUT_S = "30";
    };
  };
  # The server itself no longer runs here
  systemd.services.immich-server.enable = false;

  # Immich's machine learning for Nara is only reachable over Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3003 ];

  # The old media folder keeps the modes it had (group-readable), so the
  # backups and haoji (in the immich group) can still read it
  systemd.tmpfiles.settings = {
    immich = {
      # Override the setting from the immich module
      # 'e' means ensure existence and correct attributes
      "/backup-pool/photos/immich/" = {
        e = {
          user = config.services.immich.user;
          group = config.services.immich.group;
          mode = lib.mkForce "0750";
        };
      };
    };
  };

  users.users.immich = {
    home = "/var/cache/immich";
  };

  # A native dump of Immich's database. Immich also dumps its own database
  # into its media folder, but only when this machine is on at the time set
  # in Immich, so those can be days old. No timer: the backup job starts
  # the dump (backup.nix). Forgejo's was here until it moved to Ginza
  # (2026-10-19).
  services.postgresqlBackup = {
    enable = true;
    databases = [ "immich" ];
    startAt = [ ];
    compression = "none";
  };

  # Postgres sorts text by glibc's rules and records, per database, the
  # glibc version its indexes were built under. After an update that brings
  # a newer glibc the indexes have to be rebuilt, with the command defined
  # at the top of this file. This check fails while any database is behind,
  # and the heartbeat reports a failed unit.
  # The daily collation check and `sudo postgres-refresh-collation`
  # (modules/nixos/postgres-collation.nix; README.md here, "Postgres after
  # a glibc update"), with the services that use each database: the command
  # stops them while it rebuilds their database's indexes
  custom.postgres-collation = {
    enable = true;
    databaseServices = {
      # Forgejo moved to Ginza (2026-10-19); its old database stays here
      # until it is dropped
      forgejo = [ ];
      # Immich moved to Nara (2026-10-19); its database stays until the
      # mirror replaces the Borg backup
      immich = [ ];
      # Left over from an OnlyOffice document server; nothing runs on it
      onlyoffice = [ ];
      postgres = [ ];
      template1 = [ ];
    };
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  services.seerr = {
    enable = true;
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
  };

  services.bazarr = {
    enable = true;
    openFirewall = false;
  };

  # Paperless stays here, at home, rather than on a cloud server: the
  # documents are the most private data on this machine. It listens on this
  # machine only and is published as the Tailscale Service svc:paperless
  # (https://paperless.<tailnet>.ts.net, modules/nixos/tailscale-services.nix),
  # reachable from the other devices while this one is on. That address
  # names the tailnet, so PAPERLESS_URL is in an agenix secret.
  services.paperless = {
    enable = true;
    mediaDir = "/backup-pool/documents/paperless/media/";
    environmentFile = config.age.secrets."paperless.env".path;
    settings = {
      PAPERLESS_OCR_LANGUAGE = "por+eng";
    };
    # Paperless's own export: every document with its metadata, in a form
    # a fresh install can import again. No timer: the backup job starts it
    # before each run (backup.nix), so the export is never older than the
    # backup.
    exporter = {
      enable = true;
      onCalendar = null;
    };
  };

  custom.tailscale-services.paperless.target = "http://127.0.0.1:${toString config.services.paperless.port}";

  virtualisation = {
    docker.enable = false;
    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
      # Periodically prune Podman resources
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    oci-containers = {
      backend = "podman";
    };
  };
}
