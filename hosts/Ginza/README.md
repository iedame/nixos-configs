# Ginza

NixOS on Oracle Cloud's Always Free Ampere A1 instance (VM.Standard.A1.Flex,
aarch64-linux: 4 Arm cores and 24 GB of memory, the whole free A1
allowance). It runs **linkding**, the bookmark manager, moved here from
the Mac: `https://linkding.<tailnet>.ts.net`, the Tailscale Service
`svc:linkding`.

The machine itself (disk, boot loader, admin account) is described in
`modules/nixos/oracle-a1.nix` and `modules/nixos/oracle.nix`, which it
shares with Narita and Nikko; `default.nix` here has the name and what this
host runs.

## How it's updated

Like Narita and Nikko: CI builds the system (on GitHub's Arm runner) and
uploads all of it to the cache, and after every merge the host finds the
new system and activates it by itself (`custom.self-deploy`). The commands
in Narita's README ("How it's updated") work here with `ginza` in place of
`narita`.

## linkding

The service is published by `custom.tailscale-services` in `default.nix`.
Once, in the admin console: approve this host for `svc:linkding` (the
service already exists from the Mac). The tags allowed to reach it don't
change.

Its data is in `/var/lib/linkding`: the SQLite database, its secret key
(which keeps logins valid), favicons and previews. It moved here from the
Mac's `~/.local/share/linkding` on 2026-10-15 (the same linkding version,
1.47.0): a consistent copy of the database, taken with SQLite's backup
command, and the secret key, put in place with linkding stopped here.

### Backup

Every night it is backed up, encrypted, to the private R2 backups bucket
(`custom.linkding-backup`, `modules/nixos/linkding-backup.nix`), the same
way as Uptime Kuma on Narita and Nikko and with the same R2 token and
password (`shared/backup.env.age`). Once a week the newest copy is restored
into a scratch folder and checked: database intact, bookmarks in it, secret
key present, every file in the repository readable. Either failing shows up
in the health reports.

```bash
ssh ginza sudo restic-linkding snapshots                   # the copies
ssh ginza sudo systemctl start linkding-restore-test     # test a restore now
```

To restore, the newest copy into a scratch folder, then over the live
data with linkding stopped:

```bash
sudo restic-linkding restore latest --target /tmp/restore
sudo systemctl stop linkding-background-tasks linkding
sudo cp /tmp/restore/var/backup/linkding/db.sqlite3 /tmp/restore/var/backup/linkding/secretkey.txt /var/lib/linkding/
sudo rm -f /var/lib/linkding/db.sqlite3-wal /var/lib/linkding/db.sqlite3-shm
sudo chown -R linkding:linkding /var/lib/linkding
sudo systemctl start linkding linkding-background-tasks
sudo rm -rf /tmp/restore
```

## Installing

Converted in place from Oracle's stock Ubuntu 24.04 image for Arm, the
same way as Narita (see "Installing" in Narita's README), with these
differences:

- **No swap file is needed** for the conversion: there is enough memory.
- **The image already has `curl` and `xz`.**
- **The boot loader file is `EFI/BOOT/BOOTAA64.EFI`**, not `BOOTX64.EFI`,
  and Ubuntu's firmware entry is `0005` (`efibootmgr` shows it).
- **The SSH host key is kept**, so the key in the secrets repo's rules and
  in `lib/hosts.nix` stays valid.
- **SSH from the internet is closed** in Oracle's security list. For the
  conversion, an ingress rule allowed port 22 from one address only (the
  one doing the conversion), removed again once Tailscale was back.
