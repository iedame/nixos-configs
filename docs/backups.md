# Backups

What is backed up, where it goes, what each copy protects against, and
what isn't covered. The details (commands, restores, secrets) are in each
host's README; this page is the overview.

## What goes where

| Data | Lives on | Copy | Goes to | When | Kept | Tested |
|---|---|---|---|---|---|---|
| Documents, home folders | Aurora | Borg, `home` | Hetzner storage box | Daily, or at the next boot | 7 daily, 4 weekly, 6 monthly | Monthly repository check |
| Paperless | Aurora | Borg, `paperless` (in the `services` repository) | Hetzner storage box | Daily, or at the next boot | 7 daily, 4 weekly, 6 monthly | Monthly check, and a monthly restore against the export's checksums |
| Immich's library and its daily database dump | Nara, on the storage box (SMB) | Aurora's mirror, `external-pool/immich` | Aurora, at home | Daily when Aurora is on | 30 ZFS snapshots | Snapshot after each complete pull |
| linkding, Vaultwarden, Forgejo | Ginza | restic | Cloudflare R2, `oracle-nixos-backups` | Nightly, 03:30 | 7 daily, 4 weekly, 6 monthly | Weekly restore and full read-back; fails if the newest copy is over 48 hours old |
| Uptime Kuma | Narita, Nikko | restic | Cloudflare R2, `oracle-nixos-backups` | Nightly, 03:30 | 7 daily, 4 weekly, 6 monthly | Same as Ginza's |
| The whole storage box | Hetzner | Hetzner's snapshots | The same box, read-only | Daily, 08:00 UTC | 10 | Not tested |

Details: [Aurora](../hosts/Aurora/README.md#backups) (and its
[recovery handbook](aurora-recovery.md)), [Nara](../hosts/Nara/README.md),
[Ginza](../hosts/Ginza/README.md), [Narita](../hosts/Narita/README.md#backup).

Every failed backup, check or test fails a systemd unit, which the
heartbeat reports. Aurora's Borg jobs have no staleness alert, as the
servers' do: Aurora is often off, and while it is off its data doesn't
change either.

## What protects against what

| Threat | Defence |
|---|---|
| A file deleted or damaged by mistake | The previous night's copy (Borg, restic); for Immich, the box's snapshots first, then the mirror's |
| A disk or a whole host lost | The off-site copy: the storage box for Aurora, R2 for the servers. Immich's library survives Nara (it is on the box); its database comes back from the dump in the library |
| A backup silently unreadable | The checks and restore tests above. Hetzner's snapshots are the one copy never tested |
| The storage box lost, or the Hetzner account | Immich: Aurora's mirror. Aurora's Borg: the originals are still on Aurora, but no second off-site copy |
| The Cloudflare account lost | The servers' live data only: no second copy |
| A compromised Aurora deleting its Borg archives | The box's snapshots, out of its reach, for 10 days |
| A compromised Nara deleting photos on the share | The box's snapshots (10 days), then Aurora's mirror (30 days) |
| A compromised server deleting its restic backups | **Nothing.** See the gaps below |
| The secrets lost | Every repository password, and the R2 token, is an agenix secret and also in 1Password |

## Gaps

Open decisions, roughly by importance:

1. **R2 has no protection against deletion.** The servers' restic
   repositories can be deleted with the same token that writes them, so a
   compromised server can remove its backups. R2's bucket lock rules can
   refuse deletion for a set time, but restic deletes files itself: its
   lock files at every run, and old data when pruning. A lock rule would
   need to leave the lock files out and be shorter than what pruning
   removes, or backups start failing. Needs testing before relying on it.
2. **One R2 token and one restic password for all three servers**
   (`shared/backup.env.age`). A compromised Narita or Nikko, the smallest
   and least looked-after machines, could read Ginza's backups (the
   Vaultwarden database among them) and delete them. A token and password
   per host would contain that; R2 tokens are limited per bucket, so that
   likely means a bucket per host.
3. **Nothing on the family laptops, Kawagoe or Akihabara is backed up.**
   Files saved on the laptops exist only there. Kawagoe's backup is on the
   list, on hold.
4. **Aurora's external pool** (about 2 TB of media) and the rest listed in
   [Aurora's handbook](aurora-recovery.md#what-is-not-backed-up): on hold,
   until it is decided what is worth the space.
5. **Hetzner's snapshots are never tested.** Copying one file out of a
   snapshot now and then would show they work.

## Not backed up on purpose

Data that is cheaper to lose than to back up, so nobody goes looking for it:

- **Beszel's hub** (Ginza): history and the systems list; set up again.
- **Atuin's server** (Ginza): only ciphertext, and each machine keeps its
  full history.
- Certificates, the Nix store and Tailscale's state: re-created.
