# Postgres after a glibc update

For the hosts that run Postgres: Ginza (Forgejo's database) and Nara
(Immich's). Aurora ran it too until its services moved (2026-10-21).

Postgres sorts text by the rules of the system's C library (glibc) and
stores its text indexes in that order. Each database records the glibc
version it was last indexed under. When a NixOS update brings a newer
glibc, every connection prints

```
WARNING:  database "forgejo" has a collation version mismatch
```

because the old indexes might no longer be in the right order. Nothing is
broken by the update itself, and the backups aren't affected (a dump holds
no index order), but the warning stays until each database's indexes are
rebuilt and the new version recorded. It shows up in the logs of the
database dumps the backups make.

A daily check (`postgres-collation-check`, `custom.postgres-collation` in
`modules/nixos/postgres-collation.nix`) fails while any
database is behind, so it arrives as a failed unit in the host's health
reports (its heartbeat), within a day of the update or ten minutes after
the next boot.

To see the glibc version each database was last indexed under, next to the
system's (this changes nothing):

```bash
sudo postgres-refresh-collation
```

```
database | indexed under glibc | system glibc | state
forgejo | 2.44 | 2.44 | ok
template0 | none | 2.44 | never warns
...
```

To fix the ones marked `BEHIND`:

```bash
sudo postgres-refresh-collation --fix
```

It takes one database at a time, smallest first: stops the services that use it,
rebuilds its indexes, records the new version and starts the services
again. It ends by running the check, which clears the alert.

The command (`modules/nixos/postgres-collation.nix`) knows which services
use which database from the host's `custom.postgres-collation.databaseServices`
list (Ginza's `default.nix`, Nara's `immich.nix`). A database that isn't in that list is
skipped and the check keeps failing: add it to the list, with its services,
and rebuild.

By hand, the same thing for one database is:

```bash
sudo systemctl stop forgejo
sudo -u postgres psql -d forgejo -c 'REINDEX DATABASE forgejo' -c 'REINDEX SYSTEM forgejo' -c 'ALTER DATABASE forgejo REFRESH COLLATION VERSION'
sudo systemctl start forgejo
sudo systemctl start postgres-collation-check
```

Don't run the `ALTER DATABASE` step alone: it silences the warning without
rebuilding anything.

Last done on Aurora on 2026-10-13, for glibc 2.40 to 2.44: 3 seconds for
`forgejo`, 18 for `immich`, a second for each of the rest.
