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
| `desktop.nix` | Plasma, audio, printing, Flatpak, Bluetooth, desktop apps |
| `graphics.nix` | NVIDIA driver and OpenGL |
| `gaming.nix` | Steam, gamemode, ArchiSteamFarm, launchers and emulators |
| `backup.nix` | Off-site Borg backups of the photo library, documents and home folders |
| `services.nix` | Caddy + ACME, Immich, Forgejo, Jellyfin and the *arr apps, Paperless, Vaultwarden, linkding, Syncthing, Podman |
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
- **Services**: reached as `<name>.ts.wildtonberries.com` through Caddy, on
  the Tailscale address set at the top of `default.nix`.

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

## Backups

Two Borg jobs run daily, or when the machine is next on (`backup.nix`).
Each uploads, encrypted, to its own repository on a Hetzner Storage Box:

| Job | What | Kept |
|---|---|---|
| `immich` | `/backup-pool/photos/immich` | 7 daily, 4 weekly, 6 monthly |
| `home` | `/backup-pool/documents/haoji/onedrive` and the home folders listed in `backup.nix` | the same |

They continue the repositories Pika Backup created, with the same archive
prefixes, so the older archives are still there and are pruned by the same
rule. A failed run shows up in the health reports above. Once a month each
repository and its newest archive's index are checked for consistency;
that doesn't read the data back.

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

Everything about one backup carries the same name: the job `<name>` in
`backup.nix`, the alias `borg-<name>` in the secret SSH configuration, and
the secret `borg-<name>-passphrase`. To add one for another Storage Box
sub-account:

1. Give the sub-account the backup key (its public half is in a comment in
   `backup.nix`), with Hetzner's `install-ssh-key` command.
2. In the secrets repository, add a `Host borg-<name>` block with the
   account's `HostName` and `User` to `aurora/borg-ssh-config.age`, and
   create `aurora/borg-<name>-passphrase.age`.
3. Declare that secret in `secrets.nix` and add the job to `backup.nix`.

The storage box's account names, the SSH key it accepts and the
repository passphrases are agenix secrets (below). Without a repository's
passphrase its backup can't be read; both are also in 1Password.

## Secrets

Nine secrets are managed with agenix (`secrets.nix`; the encrypted files are
in `aurora/` of the private secrets repo), decrypted at activation into
`/run/agenix/`:

| Secret | Used by |
|---|---|
| `cloudflare-dns.env` | ACME DNS challenge for the wildcard certificate |
| `vaultwarden.env` | Vaultwarden |
| `linkding.env` | linkding |
| `heartbeat-url` | The health reports above |
| `cache-credentials` | Nix, to read the private binary cache (linked to `/root/.aws/credentials`) |
| `borg-ssh-config`, `borg-ssh-key` | The backups: how to reach the storage box, and the key for it |
| `borg-immich-passphrase`, `borg-home-passphrase` | The backups: each repository's passphrase |

To confirm the services read them:

```bash
# The decrypted secrets exist (root-only, so sudo)
sudo ls -l /run/agenix/

# Each service's environment file points into /run/agenix
systemctl show vaultwarden -p EnvironmentFiles
systemctl show linkding -p EnvironmentFiles
systemctl show acme-order-renew-ts.wildtonberries.com -p EnvironmentFiles
```

To change one, edit it on the Mac, where the editing key lives (in the
secrets repo clone, `~/.config/nixos-secrets`), push it, then bump the input and
rebuild:

```bash
cd ~/.config/nixos-secrets
agenix -e aurora/vaultwarden.env.age -i ~/.ssh/agenix
git commit -am "update vaultwarden env" && git push
cd ~/.config/nixos-configs && nix flake update secrets   # commit flake.lock, then on Aurora:
update
```

See the root README for adding new secrets.
