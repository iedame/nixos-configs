{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.postgres-collation;
  backups = config.services.postgresqlBackup;

  # `sudo postgres-refresh-collation` shows the glibc version each database
  # was last indexed under; with --fix it rebuilds the indexes of those that
  # are behind (hosts/Aurora/README.md, "Postgres after a glibc update").
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
        '') cfg.databaseServices
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

      ${lib.optionalString backups.enable ''
        echo
        echo "== fresh dumps first"
        for database in ${toString backups.databases}; do
          if echo "$behind" | grep -q -x "$database"; then
            systemctl start --wait "postgresqlBackup-$database.service"
            echo "$database: dumped"
          fi
        done
      ''}

      for database in $behind; do
        echo "== $database"
        if ! units=$(services_of "$database"); then
          echo "not listed in custom.postgres-collation.databaseServices; skipped"
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
  # Postgres sorts text by the rules of the C library (glibc) and stores its
  # text indexes in that order; after a glibc update the order can change,
  # and the indexes need rebuilding (hosts/Aurora/README.md, "Postgres after
  # a glibc update"). This adds a daily check that fails, and so is reported
  # by the heartbeat, while any database is behind, and the command that
  # rebuilds them: `sudo postgres-refresh-collation [--fix]`.
  options.custom.postgres-collation = {
    enable = lib.mkEnableOption "the daily Postgres collation check and the postgres-refresh-collation command";
    databaseServices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        forgejo = [ "forgejo.service" ];
        postgres = [ ];
      };
      description = ''
        The services that use each database, which the command stops while
        it rebuilds that database's indexes. It leaves alone any database
        not listed here, so a new service with a Postgres database gets a
        line.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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
  };
}
