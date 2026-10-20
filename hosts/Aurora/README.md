# Aurora

NixOS desktop and home server (x86_64-linux).

## Rebuild

```bash
sudo nixos-rebuild switch --flake ~/.config/nixos-configs#Aurora
```

Or use the `update` alias, which runs `nh os switch -H Aurora` (build
progress, package diff, then activation).

## Layout

| File | What's in it |
|---|---|
| `default.nix` | Imports, boot, ZFS, networking, shared modules, command-line tools |
| `users.nix` | The `haoji` account, system zsh, YubiKey (`pam_u2f`) login and sudo |
| `desktop.nix` | Plasma, audio, printing, Flatpak (updated weekly, `modules/nixos/flatpak.nix`), Bluetooth, desktop apps |
| `graphics.nix` | NVIDIA driver and OpenGL |
| `gaming.nix` | Steam, gamemode, ArchiSteamFarm, launchers and emulators |
| `backup.nix` | Off-site Borg backups of the photo library, documents and home folders |
| `services.nix` | Immich's machine learning (for Nara), Jellyfin and the *arr apps, Paperless, Syncthing, Podman |
| `ssh.nix` | SSH server (Tailscale only) |
| `secrets.nix` | agenix secrets |
| `hardware-configuration.nix` | Generated hardware settings |

## Host-specific pieces

- **SSH** (`ssh.nix`): the SSH server is reachable only over Tailscale (port
  22 is open on `tailscale0`, nowhere else), keys only, no root login. From
  the Mac: `ssh aurora`. It also provides the host key agenix decrypts with.
- **1Password SSH agent**: must be enabled in the app (Settings → Developer →
  "Use the SSH agent"). `ssh`, `git push` and commit signing depend on it;
  it's the one piece that isn't declarative.
- **Services**: reached on the Tailscale address set at the top of
  `default.nix`. Paperless is published as the Tailscale Service
  svc:paperless (`https://paperless.<tailnet>.ts.net`, open while this
  machine is on). Immich moved to Nara (2026-10-19); this host still runs
  its machine learning, on port 3003 over Tailscale, which Nara's Immich
  uses (`hosts/Nara/README.md`, "Immich").

## Health reports

Every minute this host tells an Uptime Kuma "push" monitor whether it is
healthy (`custom.heartbeat`, `modules/nixos/heartbeat.nix`). Uptime Kuma
then sends a Telegram message if a systemd unit has failed here, or if the
reports stop for longer than the monitor's heartbeat interval. This machine
is often off, so that interval is set to weeks on its monitor: silence is
normal, and the alert that matters is a failed unit.

The monitor's push URL contains the tailnet's name and a token, so it is
not in this repository: it is the agenix secret `aurora/heartbeat-url.age`
(see below).

## Drive health

`custom.disk-health` (`modules/nixos/disk-health.nix`) runs smartd over the
drives, which also has each one run a short self-test daily at 14:00, and,
every hour, a check that fails when a drive reports that it is
failing, has an attribute past its failure threshold or a failed self-test,
or when a ZFS pool isn't healthy. A failing check shows up in the health
reports above.

The 10 TB disk's USB enclosure gives no SMART answer while the disk is
spun down, so the hourly check skips it then, without waking it. A second
run, once a day, wakes any drive that didn't answer and asks again.

```bash
sudo systemctl start disk-health-full; journalctl -u disk-health-full -n 10 --no-pager -o cat   # check now, waking drives
sudo smartctl -a -d sat /dev/sdc                                                                 # one drive in full
```

## Backups

What to do when a disk is lost, step by step: [the recovery
handbook](../../docs/aurora-recovery.md).

Borg jobs run daily, or when the machine is next on (`backup.nix`). Each
uploads, encrypted, to a repository on a Hetzner Storage Box, one
sub-account per repository, and keeps 7 daily, 4 weekly and 6 monthly
archives:

| Job | What | Repository |
|---|---|---|
| `immich` | `/backup-pool/photos/immich` and a Postgres dump of Immich's database | `immich` |
| `home` | `/backup-pool/documents` (except Paperless's files) and the home folders listed in `backup.nix` | `home` |
| `paperless` | Paperless's export of every document with its metadata | `services` |

The last one makes that copy fresh before each run, and so does `immich`
for its database dump; Paperless is stopped for the moment its export
takes.

`immich` and `home` continue the repositories Pika Backup created, with
the same archive prefixes, so the older archives are still there and are
pruned by the same rule. The small services share the `services`
repository, one job each with its own archive prefix; a service that
outgrows it can be pointed at a repository of its own. A failed run shows up in the health reports above. Once a month each
repository and its newest archive's index are checked for consistency.
That doesn't read the data back, with one exception: the dump of Immich's
database in the newest archive is downloaded and checked to be complete. To
run the check now:

```bash
sudo systemctl start borgbackup-check && journalctl -u borgbackup-check -n 5 --no-pager -o cat
```

Also once a month, four of the five backups are restored into a scratch
folder and looked at (`borgbackup-restore-test-<job>`, in
`backup.nix`), because an archive can pass the check above and still hold
something useless:

| Test | Passes when |
|---|---|
| `paperless` | Every document in the export's manifest is there and matches the checksum recorded for it |
| `immich` | The database dump loads into an empty Postgres, and 25 photos picked at random from it are in the archive with the checksum Immich recorded for them |

They fail, and show up in the health reports, only on such a hard fault;
they don't start the services on the restored data, and write nothing
outside their scratch folder. `home` has no test: it holds plain files with
nothing to check them against. All four take about four minutes together.
To run one now:

```bash
sudo systemctl start borgbackup-restore-test-immich && journalctl -u borgbackup-restore-test-immich -n 3 --no-pager -o cat
```

```bash
sudo borg-job-immich list                  # archives
sudo systemctl start borgbackup-job-immich # back up now
journalctl -u borgbackup-job-immich -n 30  # what the last run did
```

To restore, mount an archive and copy out of it (`home` works the same):

```bash
sudo mkdir -p /mnt/borg && sudo borg-job-immich mount ::<archive> /mnt/borg
# ... copy what is needed from /mnt/borg ...
sudo borg-job-immich umount /mnt/borg
```

Everything about one repository carries the same name: `repo = "<name>"`
in the jobs that use it, the alias `borg-<name>` in the secret SSH
configuration, and the secret `borg-<name>-passphrase`. To add one for
another Storage Box sub-account:

1. Give the sub-account the backup key (its public half is in a comment in
   `backup.nix`), with Hetzner's `install-ssh-key` command.
2. In the secrets repository, add a `Host borg-<name>` block with the
   account's `HostName` and `User` to `aurora/borg-ssh-config.age`, and
   create `aurora/borg-<name>-passphrase.age`.
3. Declare that secret in `secrets.nix` and add the job to `backup.nix`,
   with `doInit = true` if the repository doesn't exist yet.

The storage box's account names, the SSH key it accepts and the
repository passphrases are agenix secrets (below). Without a repository's
passphrase its backup can't be read; both are also in 1Password.

## Immich's mirror

Immich runs on Nara since 2026-10-19. `immich-mirror.nix` keeps a copy of
its library here, in the ZFS dataset `external-pool/immich`: every day
this machine is on, it pulls the library from Nara over Tailscale with
rsync (only what changed), then takes a snapshot, keeping the last 30.
Immich's own database dumps are in the library's `backups/`, so they come
along. Nara accepts the job's key only for a read-only rsync of the
library (its `immich-mirror` account).

A run fails, and the heartbeat reports it, if the dataset isn't mounted,
if Nara's library looks missing (no `library/.immich`), or if it would
delete more than 2000 files; a real mass deletion then needs a run by
hand with a higher `--max-delete`.

```bash
sudo systemctl start immich-mirror                  # pull now
journalctl -u immich-mirror -n 20 --no-pager -o cat # what the last run did
zfs list -t snapshot -o name,used,creation external-pool/immich
ls /external-pool/immich/.zfs/snapshot/              # each snapshot, browsable
```

Made once by hand (2026-10-19): the dataset, seeded from the old Immich
folder on backup-pool so the first pull only brought what changed since
the move:

```bash
sudo zfs create external-pool/immich
sudo rsync -aH --info=progress2 /backup-pool/photos/immich/ /external-pool/immich/
sudo systemctl start immich-mirror
```

## Postgres after a glibc update

The same applies to Ginza, which runs Forgejo's database; its README
points here.

Postgres sorts text by the rules of the system's C library (glibc) and
stores its text indexes in that order. Each database records the glibc
version it was last indexed under. When a NixOS update brings a newer
glibc, every connection prints

```
WARNING:  database "immich" has a collation version mismatch
```

because the old indexes might no longer be in the right order. Nothing is
broken by the update itself, and the backups aren't affected (a dump holds
no index order), but the warning stays until each database's indexes are
rebuilt and the new version recorded. It shows up in the logs of the
database dumps the backups make.

A daily check (`postgres-collation-check`, `custom.postgres-collation` in
`modules/nixos/postgres-collation.nix`) fails while any
database is behind, so it arrives as a failed unit in the
[health reports](#health-reports), within a day of the update or ten
minutes after the next boot.

To see the glibc version each database was last indexed under, next to the
system's (this changes nothing):

```bash
sudo postgres-refresh-collation
```

```
database | indexed under glibc | system glibc | state
immich | 2.44 | 2.44 | ok
template0 | none | 2.44 | never warns
...
```

To fix the ones marked `BEHIND`:

```bash
sudo postgres-refresh-collation --fix
```

It makes a fresh dump of Immich's database, then takes one
database at a time, smallest first: stops the services that use it,
rebuilds its indexes, records the new version and starts the services
again. It ends by running the check, which clears the alert.

The command (`modules/nixos/postgres-collation.nix`) knows which services
use which database from the `databaseServices` list in `services.nix`
(`custom.postgres-collation`). A database that isn't in that list is
skipped and the check keeps failing: add it to the list, with its services,
and rebuild.

By hand, the same thing for one database is:

```bash
sudo -u postgres psql -d immich -c 'REINDEX DATABASE immich' -c 'REINDEX SYSTEM immich' -c 'ALTER DATABASE immich REFRESH COLLATION VERSION'
sudo systemctl start postgres-collation-check
```

Don't run the `ALTER DATABASE` step alone: it silences the warning without
rebuilding anything.

Last done on 2026-10-13, for glibc 2.40 to 2.44: 3 seconds for `forgejo`,
18 for `immich`, a second for each of the rest.

## Secrets

Ten secrets are managed with agenix (`secrets.nix`; the encrypted files are
in `aurora/` of the private secrets repo), decrypted at activation into
`/run/agenix/`:

| Secret | Used by |
|---|---|
| `heartbeat-url` | The health reports above |
| `cache-credentials` | Nix, to read the private binary cache (linked to `/root/.aws/credentials`) |
| `borg-ssh-config`, `borg-ssh-key` | The backups: how to reach the storage box, and the key for it |
| `borg-immich-passphrase`, `borg-home-passphrase`, `borg-services-passphrase` | The backups: each repository's passphrase |
| `immich-mirror-ssh-key` | Pulling the mirror of Immich's library from Nara |
| `paperless.env` | Paperless's svc:paperless address (`PAPERLESS_URL`, `PAPERLESS_ALLOWED_HOSTS`) |
| `beszel-agent.env` | Beszel's agent (shared with the other hosts) |

To confirm the services read them:

```bash
# The decrypted secrets exist (root-only, so sudo)
sudo ls -l /run/agenix/

# Each service's environment file points into /run/agenix
systemctl show beszel-agent -p EnvironmentFiles
```

To change one, edit it on the Mac, where the editing key lives (in the
secrets repo clone, `~/.config/nixos-secrets`), push it, then bump the input and
rebuild:

```bash
cd ~/.config/nixos-secrets
agenix -e aurora/heartbeat-url.age -i ~/.ssh/agenix
git commit -am "update Aurora's heartbeat URL" && git push
cd ~/.config/nixos-configs && nix flake update secrets   # commit flake.lock, then on Aurora:
update
```

See the root README for adding new secrets.
