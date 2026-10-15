# nixos-configs

NixOS and nix-darwin configuration for my machines, as a single flake with
home-manager. Layout inspired by
[matteo-pacini/nixos-configs](https://github.com/matteo-pacini/nixos-configs).

## Hosts

| Host | Platform | Role |
|---|---|---|
| [Aurora](hosts/Aurora/README.md) | NixOS, x86_64-linux | Desktop, gaming, home server (Immich, Jellyfin, Forgejo, Vaultwarden, …) |
| [Kawagoe](hosts/Kawagoe/README.md) | nix-darwin, aarch64-darwin | Mac mini |
| [Tsukuba](hosts/Tsukuba/README.md) | NixOS, x86_64-linux | Family laptop (MacBook Pro), updates itself from this repo |
| [Kawaguchiko](hosts/Kawaguchiko/README.md) | NixOS, x86_64-linux | Family laptop (MacBook Pro), the same set-up as Tsukuba |
| [Narita](hosts/Narita/README.md) | NixOS, x86_64-linux | Oracle Cloud Always Free micro instance: uptime monitoring, Tailscale exit node |
| [Nikko](hosts/Nikko/README.md) | NixOS, x86_64-linux | Oracle Cloud Always Free micro instance: uptime monitoring, Tailscale exit node |
| [Ginza](hosts/Ginza/README.md) | NixOS, aarch64-linux | Oracle Cloud Always Free Ampere A1 instance: linkding |

## Layout

```
flake.nix                 inputs, host definitions, shared module sets
hosts/<Host>/             per-host system config (+ users/haoji for home-manager)
modules/nixos/            NixOS modules        (nixosModules.default)
modules/darwin/           nix-darwin modules   (darwinModules.default)
modules/home-manager/     home-manager modules (homeModules.default)
lib/hosts.nix             the hosts' addresses and the admin SSH key, as data
```

The agenix-encrypted secrets live in a separate private repository (the
`secrets` flake input).

Shared modules are opt-in: each defines `custom.<name>.enable` and hosts turn
on what they need, e.g. `custom.nix-core.enable = true;`.

## Usage

Rebuild the current machine (Aurora and Kawagoe define this alias, which runs
`nh`; Tsukuba and Kawaguchiko update themselves weekly, and Narita and Nikko
after every merge):

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
that fails on anything unformatted or unsorted. Flake inputs are updated weekly by a GitHub
Actions PR.

## Binary cache

CI builds every host on each pull request and uploads what
`cache.nixos.org` doesn't have to a private Cloudflare R2 bucket: a short
list of packages for Aurora and the family laptops, the whole system for
Narita and Nikko, which can't build their own (`.github/workflows/ci.yml`). The NixOS
hosts download from it with `custom.nix-core.ciCache.enable`
(`modules/nixos/nix-core.nix`).

The bucket is read through R2's S3 API, so each host needs a read-only
token for it (Cloudflare dashboard, R2, "Manage API tokens": Object Read
only, limited to this bucket), in root's AWS credentials file. On Aurora,
Narita and Nikko that file is an agenix secret (`cache-credentials.age` in
`aurora/` and `shared/`; see [Secrets](#secrets)), so changing the token is
an edit there. It is placed by hand on Tsukuba and Kawaguchiko, and once on a newly
installed Narita or Nikko, which needs it to download its first system:

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

- [Aurora](docs/aurora-recovery.md): reinstalling after losing the system
  disk, re-creating the pool, and restoring each service from the backups.

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
