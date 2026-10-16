# Aurora recovery handbook

What to do when Aurora loses a disk, or all of them. Written 2026-10-13.

**Most of this procedure has not been rehearsed.** The backups it relies on
run every night and their repositories are checked monthly, but apart from
reading the archives back, only the [Vaultwarden](#vaultwarden),
[Paperless](#paperless) and [Forgejo](#forgejo) restores and a part of
[Immich's](#immichs-database) have been tried, and those into scratch
folders. Treat the other commands as the plan, and correct this file after
the first real use.

What is tested without anyone asking: once a month Aurora restores the
newest Vaultwarden, Paperless and Forgejo archives, and Immich's database
with a sample of photos, into a scratch folder, and checks them (see
"Backups" in [Aurora's README](../hosts/Aurora/README.md)). That shows the
archives hold complete, undamaged copies. It doesn't replace the steps
below, which put such a copy back in service.

## What is where

| Disk | Holds | If it dies |
|---|---|---|
| 256 GB Toshiba NVMe | `/boot`, `/` (the system, `/home`, every service's state in `/var/lib`), swap | [Reinstall](#the-system-disk-died), then restore home folders and services |
| 1 TB HGST (`backup-pool`) | `/backup-pool/photos` (Immich's library), `/backup-pool/documents` | [Re-create the pool](#the-backup-pool-disk-died) and restore from the `immich` and `home` backups |
| 10 TB WD, USB (`external-pool`) | `/external-pool/media` | [Not backed up](#what-is-not-backed-up) |
| 1 TB Samsung NVMe | `/mnt/storage`: the Steam library, `Games`, `GitHub` clones | Not backed up |
| 2 TB WD, USB | An NTFS volume Aurora doesn't mount | Nothing Aurora uses |

Both pools are a single disk each, unencrypted, with `ashift=12` and
compression on.

The backups are Borg repositories on a Hetzner Storage Box, one sub-account
each (`hosts/Aurora/backup.nix`):

| Repository | Jobs | Restores |
|---|---|---|
| `immich` | `immich` | `/backup-pool/photos/immich` (photos, videos and Immich's own database dumps) and `/var/backup/postgresql/immich.sql`, a dump of its database made just before each backup |
| `home` | `home` | `/backup-pool/documents` and the home folders listed in `backup.nix` |
| `services` | `vaultwarden`, `paperless`, `forgejo` | Each service's own export of its data |

## What you need that is not on Aurora

Check these exist before a disk fails, not after.

- **The Mac**, with this repository, the secrets repository
  (`~/.config/nixos-secrets`) and the editing key `~/.ssh/agenix`. A
  YubiKey works in place of the editing key.
- **1Password**: each Borg repository's passphrase with its exported key,
  the editing key's backup, and the Hetzner and Tailscale logins.
- **A NixOS installer** on a USB stick (the minimal ISO is enough).

Everything else can be rebuilt from those. In particular the Borg SSH key
is the agenix secret `aurora/borg-ssh-key.age`, and the storage box still
accepts it after a reinstall.

## The system disk died

The pools are untouched in this case; only the system, `/home` and the
services' state are gone.

### 1. Install a minimal NixOS

Boot the installer and partition the new disk the way the old one was: a
1 GB EFI partition (vfat) for `/boot`, an ext4 root, and swap. Mount them
under `/mnt` and generate a configuration:

```bash
sudo nixos-generate-config --root /mnt
```

Edit `/mnt/etc/nixos/configuration.nix` so the first boot is reachable:
enable `services.openssh`, create the user `haoji` in `wheel` with the admin
key from `lib/hosts.nix` in `openssh.authorizedKeys.keys`, set
`networking.hostId = "12460081";` (ZFS wants the same one as before), and
enable flakes. Then:

```bash
sudo nixos-install
```

Reboot, log in, and set a password for `haoji` with `passwd`: the config
doesn't carry one.

### 2. Tell the config about the new machine

A reinstalled Aurora has new disk identifiers and a new SSH host key. The
host key is what agenix decrypts with, so every Aurora secret has to be
encrypted again for it. On the Mac:

1. Copy the new `/etc/nixos/hardware-configuration.nix` from Aurora over
   `hosts/Aurora/hardware-configuration.nix`. If the storage disk
   survived, keep its `/mnt/storage` entry.
2. Put Aurora's new host key (`/etc/ssh/ssh_host_ed25519_key.pub`) in
   `lib/hosts.nix`.
3. In the secrets repository, put the same key in `agenix-rules.nix` as
   `aurora`, then re-encrypt and push:

   ```bash
   cd ~/.config/nixos-secrets && agenix -r -i ~/.ssh/agenix && git commit -am "rekey for the new aurora" && git push
   ```

4. Back here, `nix flake update secrets`, commit, and merge as usual.

### 3. Tailscale

On Aurora, `sudo tailscale up` and approve it in the admin console with the
tag the other desktops have. Aurora's services listen on its Tailscale
address, which is written in `lib/hosts.nix`. Either give the new node the
old address in the admin console (edit the machine's IP), or put the new
address in `lib/hosts.nix` in the commit above.

### 4. Switch to the real configuration

Evaluating the config needs the private secrets repository. Until the
1Password SSH agent is set up on the new install, hand Aurora the copy the
Mac already has. On the Mac:

```bash
src=$(nix eval --raw ~/.config/nixos-configs#nixosConfigurations.Aurora.config.age.secrets.heartbeat-url.file | sed -E 's#(/nix/store/[^/]+)/.*#\1#')
nix copy --to ssh://aurora "$src"
```

On Aurora:

```bash
git clone https://github.com/iedame/nixos-configs.git ~/.config/nixos-configs
sudo nixos-rebuild switch --flake ~/.config/nixos-configs#Aurora
```

This imports both pools by itself (`boot.zfs.extraPools`). If ZFS refuses
because the pool was last used by "another system", run
`sudo zpool import -f backup-pool` (and `external-pool`) once.

After the switch, register the YubiKey for `sudo` again; its registration
lived in the home folder:

```bash
mkdir -p ~/.config/Yubico && pamu2fcfg -o pam://yubi > ~/.config/Yubico/u2f_keys
```

### 5. Restore the data

In this order, each described under [Restoring one thing](#restoring-one-thing):

1. The home folders, from `home`.
2. Vaultwarden.
3. Forgejo.
4. Paperless.
5. Immich's database. Its photos are on the pool and need nothing.

Then sign in to 1Password and enable its SSH agent, and set up again what
has no backup: Jellyfin, the \*arr apps, Syncthing's pairings, Steam.

## The backup-pool disk died

The system still runs. Stop what writes to the pool, re-create it on the
new disk under the same name, and restore.

```bash
sudo systemctl stop immich-server immich-machine-learning paperless-web paperless-consumer paperless-scheduler paperless-task-queue syncthing
sudo zpool create -o ashift=12 -O compression=on -O mountpoint=/backup-pool backup-pool /dev/disk/by-id/<the new disk>
sudo zfs create backup-pool/photos
sudo zfs create backup-pool/documents
```

Borg stores paths without the leading `/`, so extracting from `/` puts
everything back where it was. Take the newest archive name from
`sudo borg-job-immich list` and `sudo borg-job-home list`:

```bash
cd / && sudo borg-job-immich extract --progress ::<archive>
cd / && sudo borg-job-home extract --progress ::<archive> backup-pool/documents
```

The first is about 358 GB to download, so it runs for hours. Start the
services again afterwards. Paperless's own files aren't in `home`; restore
them as described under [Paperless](#paperless).

If both this disk and the system disk are gone, do the system first, then
this.

## Restoring one thing

Every job has a command that already knows its repository, key and
passphrase: `borg-job-<name>`. The three jobs in the `services` repository
share it, so pick archives by their prefix.

```bash
sudo borg-job-vaultwarden list --glob-archives 'vaultwarden-*'
```

To look inside an archive without restoring it:

```bash
sudo mkdir -p /mnt/borg && sudo borg-job-home mount ::<archive> /mnt/borg
sudo borg-job-home umount /mnt/borg
```

To pull an archive into a scratch folder:

```bash
sudo mkdir -p /root/restore && cd /root/restore && sudo borg-job-<name> extract ::<archive>
```

The sections below assume that scratch folder. Delete it when done.

### Home folders

```bash
cd / && sudo borg-job-home extract ::<archive> home/haoji
```

Only the folders listed in `backup.nix` come back. Hidden configuration
folders aren't in the backup.

### Vaultwarden

The archive holds what Vaultwarden's own backup job wrote: a consistent
`db.sqlite3`, the attachments, sends and its RSA keys.

```bash
sudo systemctl stop vaultwarden
sudo cp -a /root/restore/var/local/vaultwarden/backup/. /var/lib/vaultwarden/
sudo rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
sudo chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
sudo systemctl start vaultwarden
```

Rehearsed on 2026-10-13, up to the copy: the newest archive was extracted
(10 seconds, under 1 MB), its database passed SQLite's integrity check and
had the same number of users, entries and attachments as the live one, the
RSA key was identical, and a second Vaultwarden started on a scratch copy of
the files and answered. Not tried: the copy over the real
`/var/lib/vaultwarden`, and logging in to the restored copy.

### Forgejo

The archive holds two things: `var/lib/forgejo/dump/forgejo-dump-<time>.tar`
(repositories, LFS files, attachments, settings) and
`var/backup/postgresql/forgejo.sql` (the database, dumped by Postgres).
Use the newest tar. Inside it are `repos`, `data`, `custom`, `app.ini` and
Forgejo's own copy of the database (`forgejo-db.sql`, not used here).

```bash
sudo systemctl stop forgejo
sudo mkdir /root/restore/dump && sudo tar -xf /root/restore/var/lib/forgejo/dump/forgejo-dump-<time>.tar -C /root/restore/dump
```

Put the `repos` folder from the dump at `/var/lib/forgejo/repositories` and
the `data` folder at `/var/lib/forgejo/data`. Leave the dump's `app.ini`
where it is: the NixOS module writes Forgejo's settings itself at every
start. Replace the database with the native dump, which re-creates it; the
`forgejo` database user it refers to has to exist already, and on a
reinstalled Aurora the NixOS module has created it:

```bash
sudo -u postgres dropdb --if-exists forgejo
sudo -u postgres psql --file /root/restore/var/backup/postgresql/forgejo.sql
sudo chown -R forgejo:forgejo /var/lib/forgejo
sudo systemctl start forgejo
```

`postgres` can't read `/root`; if `psql` says so, feed it the file instead
(`sudo cat <file> | sudo -u postgres psql`). The mirrors catch up with
their sources by themselves at the next sync.

Rehearsed on 2026-10-13 with a second Postgres and a second Forgejo in a
scratch folder, sandboxed away from the real ones: the newest archive was
extracted (about a minute, 221 MB), all 12 repositories passed `git fsck`,
the database dump loaded into an empty Postgres in 4 seconds with the same
numbers of repositories, users and releases as the live one, and Forgejo
started on the restored database and repositories, reported itself healthy
and served its login page. Not tried: the copy into the real
`/var/lib/forgejo`, logging in, and cloning a repository from the restored
copy.

### Paperless

The archive holds Paperless's export: every document plus a manifest with
its metadata. Import it into a running, empty Paperless. The import runs
as the `paperless` user, which can't read `/root`, so this one is extracted
somewhere else:

```bash
sudo mkdir -p /var/tmp/restore && cd /var/tmp/restore && sudo borg-job-paperless extract ::<archive>
sudo chown -R paperless:paperless /var/tmp/restore
sudo paperless-manage document_importer /var/tmp/restore/var/lib/paperless/export
sudo rm -rf /var/tmp/restore
```

"Running" matters: Paperless needs its Redis even to create its database,
and the import ends by rebuilding the search index in
`/var/lib/paperless/index`, a folder the service creates. The login
accounts come back (whether their passwords still work wasn't tried).
Paperless's internal `consumer` account isn't in the export.

Rehearsed on 2026-10-13 with a second Paperless in a scratch folder (its
own empty database, media folder and Redis): the newest archive was
extracted (12 seconds, 2 MB) and imported in 3 seconds, all 6 documents
came back with originals byte-identical to the live ones, and Paperless's
sanity checker found no issues. Not tried: the import into the real
service, and opening a document in the restored copy.

### Immich's database

There are two kinds of dump, and the first is the one to use:

- `var/backup/postgresql/immich.sql` in the `immich` archive: made by
  Postgres just before each backup, so it matches the photos in the same
  archive. It re-creates the `immich` database itself.
- Immich's own dumps in `/backup-pool/photos/immich/backups`
  (`immich-db-backup-<time>-v<version>-pg<version>.sql.gz`). Immich only
  makes one when Aurora is on at the time set in Immich, so the newest can
  be days older than the photos. They hold the database's contents only and
  need an existing, empty `immich` database to load into.

Either replaces the whole database, and needs the `immich` database user
to exist; on a reinstalled Aurora the NixOS module has created it. Check
the steps against "Backup and restore" in Immich's documentation for the
installed version. With the first kind:

```bash
sudo systemctl stop immich-server immich-machine-learning
sudo -u postgres dropdb --if-exists immich
sudo cat /root/restore/var/backup/postgresql/immich.sql \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | sudo -u postgres psql --dbname=postgres
sudo systemctl start immich-server immich-machine-learning
```

With one of Immich's own dumps, create the database first
(`sudo -u postgres createdb --owner=immich immich`), then use
`gunzip --stdout <dump>.sql.gz` in place of `sudo cat ...` and
`--dbname=immich` in place of `--dbname=postgres`.

Three errors about an extension called `vectors` are expected: the
database still lists that old extension, which Postgres here no longer
ships, and Immich now uses `vchord`. Any other error is a real one.

Restore a dump into the Immich version it was made with or a newer one,
never an older one. Photos uploaded after a dump was made are on the disk
but unknown to the database.

Rehearsed in part on 2026-10-13 with a second Postgres in a scratch folder,
once with each kind of dump. The Postgres dump from that evening's archive
(866 MB) was extracted in under a minute and loaded in 31 seconds with only
those three errors; Immich's own newest dump (328 MB, two days old) did the
same. Both gave the same numbers of photos, users and albums as the live
database. Each time, 25 photos picked from the restored database were then
extracted from the archive, and every one matched the checksum Immich had
recorded for it. Not tried: starting Immich on the restored database, and
restoring the whole photo folder.

## What is not backed up

So that nobody goes looking for it in a repository:

- **`/external-pool`** (2.5 TB, mostly media). An old Pika Backup
  repository of this disk exists on the second storage box, last written in
  November 2025; nothing updates it.
- **`/mnt/storage`**: the Steam library, `Games` and the `GitHub` clones.
  Games download again; push any unpushed work in the clones.
- **Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr**: settings and library
  metadata in `/var/lib`.
- **Syncthing's identity** (`/var/lib/syncthing`): devices have to be
  paired again.
- **Home folders outside the list in `backup.nix`**, including every
  hidden configuration folder, `Projects`, `SaveFiles` and `wireguard-keys`.
- **Podman volumes**, such as the ones of the `romm` containers.
- **Aurora's SSH host key and `haoji`'s password**: replaced during the
  reinstall, as described above.

Certificates, the Nix store and Tailscale's state are re-created and need
no backup.

## Restoring a lot from far away

Restoring a whole repository from the storage box to Aurora is too slow
done directly: Borg's many small requests each wait for the round trip to
Helsinki. [borg-remote-restore.md](borg-remote-restore.md) describes what
worked for 4.8 TB: a temporary cloud server next to the box, streaming to
Aurora in 20 parallel streams.

## Afterwards

Recovery is done when all of these hold:

- The Aurora monitor in Uptime Kuma is green.
- `systemctl --failed` lists nothing.
- `sudo systemctl start borgbackup-job-vaultwarden` succeeds, which proves
  the storage box, the key and the passphrase all still work.
- `sudo systemctl start disk-health-full` succeeds on the new disk.
- `systemctl list-timers 'borgbackup-*' 'disk-health*'` shows them all
  scheduled.

Then correct this file where reality differed from it.
