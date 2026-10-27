# nixos-configs

NixOS and nix-darwin configuration for my machines, as a single flake with
home-manager. It's public to be read, not used as is: it won't evaluate
without my private secrets repository (see [Secrets](#secrets)). Ideas from
other people's configurations are credited at the [end](#credits).

## Hosts

| Host | Platform | Role |
|---|---|---|
| [Aurora](hosts/Aurora/README.md) | NixOS, x86_64-linux | Desktop, gaming, home server (Jellyfin, Paperless, Immich's machine learning, …) |
| [Kawagoe](hosts/Kawagoe/README.md) | nix-darwin, aarch64-darwin | Mac mini |
| [Tsukuba](hosts/Tsukuba/README.md) | NixOS, x86_64-linux | Family laptop (MacBook Pro), updates itself from this repo |
| [Kawaguchiko](hosts/Kawaguchiko/README.md) | NixOS, x86_64-linux | Family laptop (MacBook Pro), the same set-up as Tsukuba |
| [Akihabara](hosts/Akihabara/README.md) | NixOS-WSL, x86_64-linux | Command-line NixOS under WSL on the gaming laptop (Windows 11) |
| [Narita](hosts/Narita/README.md) | NixOS, x86_64-linux | Oracle Cloud micro instance: uptime monitoring, Tailscale exit node |
| [Nikko](hosts/Nikko/README.md) | NixOS, x86_64-linux | Oracle Cloud micro instance: uptime monitoring, Tailscale exit node |
| [Ginza](hosts/Ginza/README.md) | NixOS, aarch64-linux | Oracle Cloud Ampere A1 instance: linkding, Vaultwarden, Forgejo, Beszel, Atuin |
| [Nara](hosts/Nara/README.md) | NixOS, aarch64-linux | Hetzner Cloud Arm server (CAX11) in Helsinki, for Immich next to the storage boxes |

## Layout

```
flake.nix                 inputs, host definitions, shared module sets
hosts/<Host>/             per-host system config (+ users/haoji for home-manager)
modules/nixos/            NixOS modules        (nixosModules.default)
modules/darwin/           nix-darwin modules   (darwinModules.default)
modules/home-manager/     home-manager modules (homeModules.default)
lib/hosts.nix             the hosts' addresses and the admin SSH key, as data
checks/invariants.nix     rules every host keeps, checked by `nix flake check`
docs/                     handbooks, and the register of workarounds and pins
```

The agenix-encrypted secrets live in a separate private repository (the
`secrets` flake input).

Shared modules are opt-in: each defines `custom.<name>.enable` and hosts turn
on what they need, e.g. `custom.nix-core.enable = true;`.

## Usage

How each host gets a merged change, and how to check that it did:

| Host | Updates | Check |
|---|---|---|
| Aurora, Kawagoe, Akihabara | By hand, with `update` (below) | The switch's own output; `update-diff` for what changed |
| Tsukuba, Kawaguchiko | By themselves, daily, from the next boot ([Tsukuba](hosts/Tsukuba/README.md#how-its-kept-up-to-date)) | `systemctl status nixos-upgrade` on the laptop |
| Narita, Nikko, Ginza, Nara | By themselves, about 20 minutes after a merge ([Narita](hosts/Narita/README.md#how-its-updated)) | Narita's README: whether it runs the latest system, and what a failed update means |

A failed automatic update also shows up in the hosts' health reports, as a
failed unit.

Rebuild the current machine (Aurora, Kawagoe and Akihabara define this alias, which runs
`nh`):

```bash
update
```

Without the alias (see [Secrets](#secrets) for why `update` is preferred):

```bash
sudo darwin-rebuild switch --flake ~/.config/nixos-configs#Kawagoe
sudo nixos-rebuild switch --flake ~/.config/nixos-configs#Aurora
```

Other aliases: `update-diff` (package diff between the last two system
generations), `nix-gc` (clean old generations, keeping the newest 3), and
`push-config` (push to GitHub and Codeberg).

Format with `nix fmt` (treefmt-nix): it runs nixfmt over every Nix file and
keep-sorted over the package lists, which sit between `# keep-sorted start`
and `# keep-sorted end` comments. Add a package anywhere in such a list and
`nix fmt` puts it in order. `nix flake check` includes a `formatting` check
that fails on anything unformatted or unsorted, and an `invariants` check
([checks/invariants.nix](checks/invariants.nix)) that fails when a host
breaks a rule they all keep: SSH only over Tailscale, with keys and without
root; no port open outside Tailscale; the firewall, Tailscale, the
heartbeat and Beszel on. A host that may leave a rule is named there, with
the reason. Flake inputs are updated twice a week (Tuesdays and Fridays) by
a GitHub Actions PR.

## Binary cache

CI builds every host on each pull request and uploads what
`cache.nixos.org` doesn't have to a private Cloudflare R2 bucket: a short
list of packages for Aurora and the family laptops, the whole system for
Narita, Nikko and Ginza, which don't build their own (`.github/workflows/ci.yml`). The NixOS
hosts download from it with `custom.nix-core.ciCache.enable`
(`modules/nixos/nix-core.nix`).

The bucket is read through R2's S3 API, so each host needs a read-only
token for it (Cloudflare dashboard, R2, "Manage API tokens": Object Read
only, limited to this bucket), in root's AWS credentials file. On Aurora,
Narita, Nikko and Ginza that file is an agenix secret (`cache-credentials.age` in
`aurora/` and `shared/`; see [Secrets](#secrets)), so changing the token is
an edit there. It is placed by hand on Tsukuba and Kawaguchiko, and once on a newly
installed Narita, Nikko or Ginza, which needs it to download its first system:

```bash
ssh -t <host> 'sudo install -d -m 700 /root/.aws && sudo sh -c "umask 077; cat > /root/.aws/credentials"'
```

Then paste these three lines and press Ctrl-D:

```ini
[default]
aws_access_key_id = <access key ID>
aws_secret_access_key = <secret access key>
```

To replace the token, put the new one in both secrets and let Narita and
Nikko deploy it before revoking the old one in Cloudflare: they download
the system that carries the new token with the old one.

A host without the file still works: Nix prints a warning and uses
`cache.nixos.org` alone, which means compiling the missing packages itself
(Narita and Nikko can't, and fail to update instead).

## Recovery

- [Restoring a large Borg archive from far away](docs/borg-remote-restore.md):
  the October 2026 restore of 4.8 TB from Helsinki, with the commands.
- [Aurora](docs/aurora-recovery.md): reinstalling after losing the system
  disk, re-creating the pool, and restoring each service from the backups.

## Workarounds and pins

[docs/workarounds.md](docs/workarounds.md) lists every temporary fix and
every version pinned for a reason, each with what makes it removable.
Check it after each lock update.

## Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix) and
kept in a separate private repository, which this flake pulls in as the
`secrets` input (`git+ssh`, see `flake.nix`). Only the input's URL and commit
hash appear here.

Each secret can be decrypted by:

- **The host's SSH host key**, at activation, into `/run/agenix/<name>`. Each
  host can only read its own secrets.
- **My editing key** (`~/.ssh/agenix` on Kawagoe, passphrase-protected, backed
  up in 1Password), for creating and changing secrets.
- **Two YubiKeys** as recovery keys (`age-plugin-yubikey`): the physical key,
  its PIV PIN and a touch.

What this means in practice:

- **Evaluating the config needs access to the private repo.** `update` (nh)
  evaluates as my user and fetches it with my SSH key. Plain
  `sudo darwin-rebuild` / `sudo nixos-rebuild` evaluate as root, which has no
  SSH key, and only work while that input is already in the Nix store.
- **Changing a secret is two steps**: commit and push in the secrets repo
  (cloned at `~/.config/nixos-secrets`; its README has the agenix commands), then
  here:

  ```bash
  nix flake update secrets
  update
  ```

- **New secret**: add it to the secrets repo, then declare
  `age.secrets.<name>.file = "${inputs.secrets}/<host>/<name>.age"` in
  `hosts/<Host>/secrets.nix` and point the service at
  `config.age.secrets.<name>.path`.
- **CI** fetches the input with a read-only deploy key (repository secret
  `SECRETS_DEPLOY_KEY`).

If you're not me, the config won't evaluate as is: remove the `secrets` input
and the `age.secrets` declarations, or point them at your own. Tsukuba and
Kawaguchiko are the exception: they use no secrets, because they update
themselves from this public repository.

## Credits

Ideas taken from other people's configurations, with thanks:

- [matteo-pacini/nixos-configs](https://github.com/matteo-pacini/nixos-configs):
  the layout (shared opt-in modules, `hosts/<Host>/` with per-user
  home-manager), rebooting servers for a new kernel, Atuin for shell
  history, and enforcing Nix's build sandbox in CI.
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config): the
  [register of workarounds and pins](docs/workarounds.md), and pinning
  GitHub Actions to commits. His
  [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) is a good
  place to start with flakes.
- [Defelo's infra flake](https://radicle.defelo.de/nodes/radicle.defelo.de/rad:z24n4G1scWV247PfW2VPSEBTFj84n):
  failing CI on evaluation warnings, the reboot notice on Aurora,
  `needrestart` after an update, and pinning the storage boxes' host key.
