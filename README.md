# nixos-configs

NixOS and nix-darwin configuration for my machines, as a single flake with
home-manager. Layout inspired by
[matteo-pacini/nixos-configs](https://github.com/matteo-pacini/nixos-configs).

## Hosts

| Host | Platform | Role |
|---|---|---|
| [Aurora](hosts/Aurora/README.md) | NixOS, x86_64-linux | Desktop, gaming, home server (Immich, Jellyfin, Forgejo, Vaultwarden, …) |
| [Kawagoe](hosts/Kawagoe/README.md) | nix-darwin, aarch64-darwin | Mac mini |
| [Tsukuba](hosts/Tsukuba/README.md) | NixOS, x86_64-linux | Family laptop (2011 MacBook Pro), updates itself from this repo |
| [Narita](hosts/Narita/README.md) | NixOS, x86_64-linux | Oracle Cloud Always Free micro instance: uptime monitoring, Tailscale exit node |
| [Nikko](hosts/Nikko/README.md) | NixOS, x86_64-linux | Oracle Cloud Always Free micro instance: uptime monitoring, Tailscale exit node |

## Layout

```
flake.nix                 inputs, host definitions, shared module sets
hosts/<Host>/             per-host system config (+ users/haoji for home-manager)
modules/nixos/            NixOS modules        (nixosModules.default)
modules/darwin/           nix-darwin modules   (darwinModules.default)
modules/home-manager/     home-manager modules (homeModules.default)
overlays/                 package overrides
```

The agenix-encrypted secrets live in a separate private repository (the
`secrets` flake input).

Shared modules are opt-in: each defines `custom.<name>.enable` and hosts turn
on what they need, e.g. `custom.nix-core.enable = true;`.

## Usage

Rebuild the current machine (Aurora and Kawagoe define this alias, which runs
`nh`; Tsukuba updates itself):

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
and the `age.secrets` declarations, or point them at your own. Tsukuba is the
exception: it uses no secrets, because it updates itself from this public
repository.
