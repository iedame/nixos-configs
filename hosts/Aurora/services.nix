{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Aurora's Tailscale address; services bind here so they're tailnet-only
  tailscaleIp = (import ../../lib/hosts.nix).hosts.Aurora.address;
  # Services behind Caddy live under this domain (wildcard ACME cert)
  domain = "ts.wildtonberries.com";
in

{
  # Enable Syncthing
  services.syncthing = {
    enable = true;
  };

  # Enable Caddy
  services.caddy = {
    enable = true;
    virtualHosts = {
      "immich.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:2283";
        useACMEHost = domain;
      };
      "git.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:3000";
        useACMEHost = domain;
      };
    };
  };

  # Caddy is only reachable over Tailscale
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      80
      443
    ];
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "git@ieda.me";
    certs = {
      ${domain} = {
        domain = "*.${domain}";
        group = "caddy";
        dnsProvider = "cloudflare";
        environmentFile = config.age.secrets."cloudflare-dns.env".path;
      };
    };
  };

  services.immich = {
    enable = true;
    host = tailscaleIp;
    port = 2283;
    mediaLocation = "/backup-pool/photos/immich/";
    machine-learning.environment = {
      HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      XDG_CACHE_HOME = "/var/cache/immich";
    };
  };

  # Allowing immich group to have mediaLocation backup permissions
  systemd.services.immich-server.serviceConfig = {
    # UMask 007 overrides the module's default (0077) for the server process,
    # ensuring new files get group read/write (660/770).
    UMask = lib.mkForce "007";
  };

  # Same for main Immich folder on reboot
  systemd.tmpfiles.settings = {
    immich = {
      # Override the setting from the immich module
      # 'e' means ensure existence and correct attributes
      "/backup-pool/photos/immich/" = {
        # Replace with your actual mediaLocation if different
        e = {
          user = config.services.immich.user;
          group = config.services.immich.group;
          mode = lib.mkForce "0750"; # Example: Owner read/write/execute, Group read/execute, Others none
        };
      };
    };
  };

  users.users.immich = {
    home = "/var/cache/immich";
  };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = tailscaleIp;
        ROOT_URL = "https://git.${domain}/";
        HTTP_PORT = 3000;
      };
      service.DISABLE_REGISTRATION = true;
      service.REQUIRE_SIGNIN_VIEW = true;
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
    };
    # Forgejo's own dump of the repositories, LFS files, attachments and
    # settings, for the off-site backup (backup.nix), which also starts it
    # before each run. An uncompressed archive, so that the backup can
    # tell what changed since the previous one; dumps older than two days
    # are removed from this disk.
    dump = {
      enable = true;
      type = "tar";
      age = "2d";
    };
  };

  # Native dumps of the databases of Forgejo and Immich. Forgejo's
  # documentation recommends relying on this one for a restore. Immich also
  # dumps its own database into its media folder, but only when this
  # machine is on at the time set in Immich, so those can be days old. No
  # timer: the backup jobs start the dumps (backup.nix).
  services.postgresqlBackup = {
    enable = true;
    databases = [
      "forgejo"
      "immich"
    ];
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
      forgejo = [ "forgejo.service" ];
      immich = [
        "immich-server.service"
        "immich-machine-learning.service"
      ];
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

  services.paperless = {
    enable = true;
    mediaDir = "/backup-pool/documents/paperless/media/";
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
