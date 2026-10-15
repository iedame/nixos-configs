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
- **Health reports** (`custom.heartbeat`, `modules/darwin/heartbeat.nix`): a
  root launchd job tells an Uptime Kuma "push" monitor every minute that
  this Mac is up, and whether the background jobs it is told to watch
  (none at the moment) are loaded and didn't last end in an error. Uptime
  Kuma sends a Telegram message if a report says otherwise or the reports
  stop. The push URL is the agenix secret `kawagoe/heartbeat-url.age`. Log
  (only when the monitor can't be reached): `/var/log/heartbeat.log`.
- **nixkeeper start-runs** (`nixkeeper-start-runs.nix`), switched off:
  Narita starts nixkeeper's runs through the GitHub API every hour. To do
  it from here while Narita is down, set
  `custom.nixkeeper-start-runs.enable = true` in `default.nix` and rebuild;
  that adds a user launchd agent (hourly at :15) and has the health reports
  watch it. Its token is the Keychain item `nixkeeper-start-runs`, which
  has to be one valid for the `nixkeeper` organisation's repositories. Log:
  `~/Library/Logs/nixkeeper-start-runs.log`.
- **linkding** ran here until October 2026 and moved to
  [Ginza](../Ginza/README.md). The old data is still in
  `~/.local/share/linkding` until deleted.
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
