# Ginza

NixOS on Oracle Cloud's Always Free Ampere A1 instance (VM.Standard.A1.Flex,
aarch64-linux: 4 Arm cores and 24 GB of memory, the whole free A1
allowance). It runs **linkding**, the bookmark manager, moved here from
the Mac: `https://linkding.<tailnet>.ts.net`, the Tailscale Service
`svc:linkding`; **Beszel**'s hub, a dashboard of all the hosts:
`https://beszel.<tailnet>.ts.net`, `svc:beszel`; **Atuin**'s sync
server for shell history: `https://atuin.<tailnet>.ts.net`, `svc:atuin`;
and **Vaultwarden**, the password manager, moved here from Aurora:
`https://vault.<tailnet>.ts.net`, `svc:vault`.

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

## Beszel

The hub (`services.beszel.hub`) shows each host's CPU, memory, disk,
network, temperatures and services, with history, and can alert on
thresholds (a disk over 90%, say). The hosts run Beszel's agent, which
sends their data to the hub.

It is published by `custom.tailscale-services` in `default.nix`. Once, in
the admin console: define the service `svc:beszel` (port 443), approve this
host for it, and let the tags that should see the dashboard reach it.

Its data (accounts, the systems list, history) is in `/var/lib/beszel-hub`
and isn't backed up: losing it costs the history and setting the systems
up again, nothing else.

## Atuin

The server (`services.atuin`) syncs shell history between Kawagoe,
Akihabara and Aurora (`custom.atuin`, `modules/home-manager/atuin.nix`).
The clients encrypt the history before sending it, so the server only
stores ciphertext. Its database is SQLite in `/var/lib/atuin`, not backed
up: each machine keeps its own full copy.

Once, in the admin console: define the service `svc:atuin` (port 443),
approve this host for it, and let the tags of the machines that sync reach
it.

The server's address names the tailnet, so it isn't in this repository.
On each machine, put it in a file, then `update`, which writes it into
Atuin's config file (until then Atuin's address goes nowhere):

```bash
mkdir -p ~/.config/atuin && echo 'https://atuin.<tailnet>.ts.net' > ~/.config/atuin/sync-address
update
```

On the first machine (Kawagoe), make the account,
bring in the existing history, and show the encryption key:

```bash
atuin register -u <user> -e <email>
atuin import auto && atuin sync
atuin key
```

The key decrypts the history; keep it in 1Password. On the other
machines, log in with it:

```bash
atuin login -u <user> -k '<key>'
atuin import auto && atuin sync
```

Registration is closed (`services.atuin.openRegistration`, `default.nix`):
the account exists, and new machines only log in. To make another account,
open it for a moment the same way.

## Vaultwarden

The server (`services.vaultwarden`) keeps everything in
`/var/lib/vaultwarden`: the SQLite database, the RSA key that signs
logins, and attachments and sends once used. Its address and admin token
are in the agenix secret `ginza/vaultwarden.env.age` (`DOMAIN=` and
`ADMIN_TOKEN=`, otherwise the same settings Aurora had).

Once, in the admin console: define the service `svc:vault` (port 443),
approve this host for it, and let the tags of the devices that use the
vault reach it.

### Moving the data from Aurora

Aurora's server stops first, so nothing changes in its database during
the copy. The user IDs differ between the hosts, hence the `chown`. The copy keeps the RSA key, so the clients' sessions remain
valid, and the database, so the accounts and items are the same.

```bash
ssh -t aurora 'sudo systemctl stop vaultwarden && sudo tar -C /var/lib -czf /tmp/vaultwarden.tar.gz vaultwarden && sudo chown haoji /tmp/vaultwarden.tar.gz'
scp aurora:/tmp/vaultwarden.tar.gz ginza:/tmp/
ssh -t ginza 'sudo systemctl stop vaultwarden && sudo rm -rf /var/lib/vaultwarden.old && sudo mv /var/lib/vaultwarden /var/lib/vaultwarden.old && sudo tar -C /var/lib -xzf /tmp/vaultwarden.tar.gz && sudo chown -R vaultwarden:vaultwarden /var/lib/vaultwarden && sudo systemctl start vaultwarden'
ssh aurora rm /tmp/vaultwarden.tar.gz
ssh ginza rm /tmp/vaultwarden.tar.gz
```

Then each client's server address changes to the new one. A YubiKey or
passkey registered as two-step login is tied to the old address: log in
with another method or the recovery code, and register it again.

### Backup

Every night it is backed up, encrypted, to the private R2 backups bucket
(`custom.vaultwarden-backup`, `modules/nixos/vaultwarden-backup.nix`), like
linkding, with the same R2 token and password (`shared/backup.env.age`).
Once a week the newest copy is restored into a scratch folder and checked:
database intact, accounts and items in it, RSA key present, every file in
the repository readable.

```bash
ssh ginza sudo restic-vaultwarden snapshots                   # the copies
ssh ginza sudo systemctl start vaultwarden-restore-test     # test a restore now
```

To restore, the newest copy into a scratch folder, then over the live
data with Vaultwarden stopped:

```bash
sudo restic-vaultwarden restore latest --target /tmp/restore
sudo systemctl stop vaultwarden
sudo cp -a /tmp/restore/var/backup/vaultwarden/. /var/lib/vaultwarden/
sudo rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
sudo chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
sudo systemctl start vaultwarden
sudo rm -rf /tmp/restore
```
