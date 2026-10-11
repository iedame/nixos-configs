# Kawagoe

Mac mini, nix-darwin + home-manager (aarch64-darwin).

## Rebuild

```bash
sudo darwin-rebuild switch --flake ~/.config/nixos-configs#Kawagoe
```

Or use the `update` alias, which runs `nh darwin switch` (build progress,
package diff, then activation). The Mac's hostname is set to `Kawagoe`
(`networking.hostName`), so both tools find the config by hostname and
`#Kawagoe` is optional.

## Host-specific pieces

- **`gha <pr-number>`** (`users/haoji/zsh.nix`): triggers a nixpkgs-review run
  for a nixpkgs PR on GitHub Actions (`iedame/nixpkgs-review-gha`).
- **nixkeeper start-runs** (`nixkeeper-start-runs.nix`): user launchd agent that
  starts nixkeeper's runs through the GitHub API every hour at :15. Its token is
  the Keychain item `nixkeeper-start-runs`. Log:
  `~/Library/Logs/nixkeeper-start-runs.log`.
- **linkding** (`custom.linkding`, `modules/home-manager/darwin/linkding.nix`, part of the darwin-only `homeModules.darwin`):
  the bookmark manager as two user launchd agents, the web server on
  `127.0.0.1:9090` and the background-task worker, with data in
  `~/.local/share/linkding`. `linkding-manage <command>` runs Django management
  commands against it (e.g. `linkding-manage createsuperuser`). Logs:
  `~/Library/Logs/linkding*.log`. nixpkgs' package is Linux-only for now, so
  `overlays/Kawagoe/linkding.nix` carries a copy with the darwin fix; it can
  go once that lands in nixpkgs. Its environment file is an agenix secret
  (`secrets.nix`). The tailnet reaches it at `https://linkding.<tailnet>.ts.net`,
  a Tailscale Service (`svc:linkding`) that follows linkding if it moves to
  another host. It is set up by hand, not by this config: define the service
  and approve this host in the admin console, allow the devices' tags to
  reach `svc:linkding` in the access rules, and advertise it here once with
  `sudo tailscale serve --service=svc:linkding --https=443 127.0.0.1:9090`
  (`tailscale serve status` shows it; Tailscale keeps it across reboots).
  Aurora's instance (NixOS's `services.linkding`) is switched off while this
  one is being tried out.
- **Intel builds**: `custom.nix-core.extraPlatforms` adds `x86_64-darwin`
  (via Rosetta).
- **Build limits**: `custom.nix-core.build` caps Nix at 2 builds at a time
  with 4 cores each, so big builds don't make the Mac unusable.
- **sudo with a YubiKey** (`system.nix`): `pam_u2f` in `/etc/pam.d/sudo_local`;
  a touch replaces the password, which still works without the key. The key
  registrations are an agenix secret, decrypted to `/etc/u2f_mappings`.
- **macOS settings** (`defaults.nix`): Dock (including the pinned apps),
  Finder, input and menu bar settings, applied on every switch; change them
  there rather than in System Settings. `system.nix` also sets the hostname,
  the application firewall (stealth mode on) and restart after power failure.
- **Secrets** (`secrets.nix`): agenix, decrypting with the macOS SSH host key;
  see the root README.
- **Homebrew** (`homebrew.nix`): Homebrew itself comes from nix-homebrew,
  with the core/cask taps pinned as flake inputs, so `brew update` is off and
  versions move with the weekly flake update. Casks are declared in
  `homebrew.casks`; anything installed with `brew` by hand is uninstalled on
  the next switch. Microsoft Office/Teams update themselves via Microsoft
  AutoUpdate. Mac App Store apps are declared in `homebrew.masApps`; removing
  one there does not uninstall it.
