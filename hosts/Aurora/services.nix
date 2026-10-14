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

  # The services that use each Postgres database, for the command below: it
  # stops them while it rebuilds their database's indexes, and leaves alone
  # any database that isn't listed here. A new service with a Postgres
  # database gets a line.
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

  # `sudo postgres-refresh-collation` shows the glibc version each database
  # was last indexed under; with --fix it rebuilds the indexes of those that
  # are behind (README.md here, "Postgres after a glibc update").
  postgres-refresh-collation = pkgs.writeShellApplication {
    name = "postgres-refresh-collation";
    runtimeInputs = [
      config.services.postgresql.package
      config.systemd.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.util-linux
    ];
    text = ''
      if [ "$(id -u)" != 0 ]; then
        echo "run with sudo"
        exit 1
      fi

      # Every connection to a database that is behind prints the warning
      # this command is about; it is left out of the output here
      sql() {
        (cd / && runuser -u postgres -- psql --no-psqlrc --tuples-only --no-align --set ON_ERROR_STOP=1 "$@") \
          2> >(grep -v -E 'collation version mismatch|was created using collation|Rebuild all objects' >&2 || true)
      }
      report() {
        echo "database | indexed under glibc | system glibc | state"
        sql --dbname=postgres --field-separator=' | ' --command="
          SELECT datname, coalesce(datcollversion, 'none'),
            coalesce(pg_database_collation_actual_version(oid), 'none'),
            CASE WHEN datcollversion IS NULL THEN 'never warns'
                 WHEN datcollversion <> pg_database_collation_actual_version(oid) THEN 'BEHIND'
                 ELSE 'ok' END
          FROM pg_database ORDER BY datname"
      }
      services_of() {
        case "$1" in
      ${lib.concatStrings (
        lib.mapAttrsToList (database: units: ''
          ${database}) echo "${toString units}" ;;
        '') databaseServices
      )}
          *) return 1 ;;
        esac
      }

      report
      if [ "$#" -eq 0 ] || [ "$1" != --fix ]; then
        echo
        echo "Report only. To rebuild the indexes of the databases that are behind:"
        echo "  sudo postgres-refresh-collation --fix"
        exit 0
      fi

      behind=$(sql --dbname=postgres --command="
        SELECT datname FROM pg_database
        WHERE datallowconn AND datcollversion IS NOT NULL
          AND datcollversion <> pg_database_collation_actual_version(oid)
        ORDER BY pg_database_size(oid)")
      if [ -z "$behind" ]; then
        echo
        echo "Nothing to do."
        exit 0
      fi

      echo
      echo "== fresh dumps first"
      for database in ${toString config.services.postgresqlBackup.databases}; do
        if echo "$behind" | grep -q -x "$database"; then
          systemctl start --wait "postgresqlBackup-$database.service"
          echo "$database: dumped"
        fi
      done

      for database in $behind; do
        echo "== $database"
        if ! units=$(services_of "$database"); then
          echo "not listed in databaseServices (services.nix); skipped"
          continue
        fi
        running=""
        for unit in $units; do
          if systemctl is-active --quiet "$unit"; then
            running="$running $unit"
          fi
        done
        if [ -n "$running" ]; then
          # shellcheck disable=SC2086
          systemctl stop $running
          echo "stopped:$running"
        fi
        started=$(date +%s)
        result=yes
        sql --dbname="$database" \
          --command="REINDEX DATABASE \"$database\"" \
          --command="REINDEX SYSTEM \"$database\"" \
          --command="ALTER DATABASE \"$database\" REFRESH COLLATION VERSION" > /dev/null || result=no
        echo "indexes rebuilt and version recorded: $result, $(($(date +%s) - started)) s"
        if [ -n "$running" ]; then
          # shellcheck disable=SC2086
          systemctl start $running
          echo "started:$running"
        fi
      done

      echo
      report
      echo
      if systemctl start postgres-collation-check.service; then
        echo "The check passes; the alert clears with the next health report."
      else
        echo "The check still fails: a database above was skipped or could not be rebuilt."
        exit 1
      fi
    '';
  };
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
      "linkding.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:9090";
        useACMEHost = domain;
      };
      "git.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:3000";
        useACMEHost = domain;
      };
      "vault.${domain}" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT} {
            header_up X-Real-IP {remote_host}
          }
        '';
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
  environment.systemPackages = [ postgres-refresh-collation ];

  systemd.services.postgres-collation-check = {
    description = "Check that no Postgres database needs its indexes rebuilt after a glibc update";
    after = [ "postgresql.service" ];
    path = [ config.services.postgresql.package ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
    };
    script = ''
      behind=$(psql --no-psqlrc --tuples-only --no-align --dbname=postgres --command="
        SELECT string_agg(datname, ', ' ORDER BY datname) FROM pg_database
        WHERE datcollversion IS NOT NULL
          AND datcollversion <> pg_database_collation_actual_version(oid)" 2> /dev/null)
      if [ -n "$behind" ]; then
        echo "glibc has changed since these databases were last indexed: $behind"
        echo "to rebuild their indexes: sudo postgres-refresh-collation --fix"
        exit 1
      fi
      echo "every database is indexed under the current glibc"
    '';
  };
  systemd.timers.postgres-collation-check = {
    description = "Check the Postgres databases' collation versions";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "10min";
      Persistent = true;
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

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/local/vaultwarden/backup";
    # ADMIN_TOKEN etc. come from an agenix secret (secrets.nix) rather than
    # the Nix store
    environmentFile = config.age.secrets."vaultwarden.env".path;
    config = {
      # Refer to https://github.com/dani-garcia/vaultwarden/blob/main/.env.template
      DOMAIN = "https://vault.${domain}/";
      SIGNUPS_ALLOWED = false;

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };

  services.linkding = {
    # Off while the copy on Kawagoe is being tried out; the data stays in
    # /var/lib/linkding
    enable = false;
    port = 9090;
    address = tailscaleIp;
    environmentFile = config.age.secrets."linkding.env".path;
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
