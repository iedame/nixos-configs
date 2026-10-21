# Aurora recovery handbook

What to do when Aurora loses a disk, or all of them. Written 2026-10-13.

**Most of this procedure has not been rehearsed.** The backups it relies on
run every night and their repositories are checked monthly, but apart from
reading the archives back, only the [Paperless](#paperless) restore has
been tried, into a scratch folder. Treat the other commands as the plan, and correct this file after
the first real use.

What is tested without anyone asking: once a month Aurora restores the
newest Paperless archive into a scratch folder and checks it (see
"Backups" in [Aurora's README](../hosts/Aurora/README.md)). That shows the
archives hold complete, undamaged copies. It doesn't replace the steps
below, which put such a copy back in service.

## What is where

| Disk | Holds | If it dies |
|---|---|---|
| 256 GB Toshiba NVMe | `/boot`, `/` (the system, `/home`, every service's state in `/var/lib`), swap | [Reinstall](#the-system-disk-died), then restore home folders and services |
| 1 TB HGST (`backup-pool`) | `/backup-pool/photos`, `/backup-pool/documents` | [Re-create the pool](#the-backup-pool-disk-died) and restore from the `home` backup |
| 10 TB WD, USB (`external-pool`) | `/external-pool/media`; `/external-pool/immich`, the mirror of Immich's library | Media: [not backed up](#what-is-not-backed-up). The mirror: re-create the dataset and let it pull again from Nara (Aurora's README, "Immich's mirror"): the whole library, over the internet |
| 1 TB Samsung NVMe | `/mnt/storage`: the Steam library, `Games`, `GitHub` clones | Not backed up |
| 2 TB WD, USB | An NTFS volume Aurora doesn't mount | Nothing Aurora uses |

Both pools are a single disk each, unencrypted, with `ashift=12` and
compression on.

The backups are Borg repositories on a Hetzner Storage Box, one sub-account
each (`hosts/Aurora/backup.nix`):

| Repository | Jobs | Restores |
|---|---|---|
| `home` | `home` | `/backup-pool/documents` and the home folders listed in `backup.nix` |
| `services` | `paperless` (and `vaultwarden` and `forgejo` archives from before they moved to Ginza) | Each service's own export of its data |

Immich isn't on Aurora any more: it runs on Nara since 2026-10-19, and its
photos are backed up by the mirror above. Restoring it is in
[Nara's README](../hosts/Nara/README.md), "Restoring Immich".

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
2. Paperless.

Immich's machine learning, which Nara uses, needs nothing restored: it
downloads its models again.

Then sign in to 1Password and enable its SSH agent, and set up again what
has no backup: Jellyfin, the \*arr apps, Syncthing's pairings, Steam.

## The backup-pool disk died

The system still runs. Stop what writes to the pool, re-create it on the
new disk under the same name, and restore.

```bash
sudo systemctl stop paperless-web paperless-consumer paperless-scheduler paperless-task-queue syncthing
sudo zpool create -o ashift=12 -O compression=on -O mountpoint=/backup-pool backup-pool /dev/disk/by-id/<the new disk>
sudo zfs create backup-pool/photos
sudo zfs create backup-pool/documents
```

Borg stores paths without the leading `/`, so extracting from `/` puts
everything back where it was. Take the newest archive name from
`sudo borg-job-home list`:

```bash
cd / && sudo borg-job-home extract --progress ::<archive> backup-pool/documents
```

Start the services again afterwards. Paperless's own files aren't in `home`; restore
them as described under [Paperless](#paperless).

If both this disk and the system disk are gone, do the system first, then
this.

## Restoring one thing

Every job has a command that already knows its repository, key and
passphrase: `borg-job-<name>`. The `services` repository also holds the
archives of the services that moved to Ginza, so pick archives by their
prefix.

```bash
sudo borg-job-paperless list --glob-archives 'paperless-*'
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

Vaultwarden moved to Ginza on 2026-10-18 and is no longer restored here:
see [Ginza's README](../hosts/Ginza/README.md), "Vaultwarden". Its archives
from before the move stay in the `services` repository under the prefix
`vaultwarden` (`sudo borg-job-paperless list --glob-archives
'vaultwarden-*'`).

### Forgejo

Forgejo moved to Ginza on 2026-10-19 and is no longer restored here: see
[Ginza's README](../hosts/Ginza/README.md), "Forgejo". Its archives from
before the move stay in the `services` repository under the prefix
`forgejo` (`sudo borg-job-paperless list --glob-archives 'forgejo-*'`).

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

### Immich

Moved to Nara (2026-10-19): see "Restoring Immich" in
[Nara's README](../hosts/Nara/README.md).

## What is not backed up

So that nobody goes looking for it in a repository:

- **`/external-pool/media`** (about 2 TB). An old Pika Backup
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
- `sudo systemctl start borgbackup-job-paperless` succeeds, which proves
  the storage box, the key and the passphrase all still work.
- `sudo systemctl start disk-health-full` succeeds on the new disk.
- `systemctl list-timers 'borgbackup-*' 'disk-health*'` shows them all
  scheduled.

Then correct this file where reality differed from it.
