# Akihabara

NixOS under WSL 2 ([NixOS-WSL](https://github.com/nix-community/NixOS-WSL))
on the gaming laptop, an Acer Predator Helios Neo 16 with Windows 11
(x86_64-linux). Windows keeps the games, the desktop apps, the drivers and
Tailscale; this host is the command line: zsh, git, nh, Claude Code and the
rest of the home-manager set-up, as on Kawagoe.

What it leaves out, because Windows has it or WSL can't: a desktop, the
NVIDIA driver (WSL uses the Windows one; `wsl.useWindowsDriver`), boot
loader and disks, YubiKey login, the heartbeat (WSL only runs while it's
used) and agenix (nothing here needs a secret).

## How it connects

- **Network and Tailscale:** WSL shares Windows' network in mirrored mode
  (`.wslconfig` below), so the tailnet the Windows Tailscale app joins is
  reachable from here too, `ssh aurora` included. Akihabara isn't a tailnet
  device of its own.
- **SSH keys and commit signing:** 1Password on Windows holds the keys.
  NixOS-WSL's bridge (`wsl.ssh-agent`) makes its SSH agent available here
  as `SSH_AUTH_SOCK`; ssh uses it (`modules/home-manager/ssh.nix`) and git
  signs with plain `ssh-keygen` through it (`modules/home-manager/git.nix`).
- **sudo** asks for no password, NixOS-WSL's default: getting a shell here
  already takes a Windows login.

## Install

On Windows:

1. 1Password: Settings > Developer > "Use the SSH agent".
2. In `%UserProfile%\.wslconfig`:
   ```ini
   [wsl2]
   networkingMode=mirrored
   ```
3. In PowerShell: `wsl --install --no-distribution` if WSL isn't installed
   yet (then restart Windows), otherwise `wsl --update`.
4. Download `nixos.wsl` from the
   [latest NixOS-WSL release](https://github.com/nix-community/NixOS-WSL/releases/latest)
   and, from the folder it is in: `wsl --install --from-file nixos.wsl`.

In NixOS (`wsl -d NixOS`, as the image's user `nixos`), switch to this
configuration. The user name changes from `nixos` to `haoji`, which needs
`boot` instead of `switch` and a restart of WSL. The image doesn't enable
flakes yet, hence `NIX_CONFIG` (this configuration does):

```bash
sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild boot --flake github:iedame/nixos-configs#Akihabara
exit
```

Back in PowerShell:

```powershell
wsl -t NixOS
wsl -d NixOS --user root exit
wsl -t NixOS
wsl -d NixOS
```

That opens a shell as `haoji`. Clone the repository, which also checks that
the 1Password agent works (it asks to approve the key):

```bash
git clone git@github.com:iedame/nixos-configs.git ~/.config/nixos-configs
```

From then on, `update` (`nh os switch -H Akihabara`) applies changes.

## Terminal

The terminal window runs on Windows and opens the shell here. Alacritty
(`winget install Alacritty.Alacritty`), in
`%APPDATA%\alacritty\alacritty.toml`:

```toml
[terminal.shell]
program = "wsl.exe"
args = ["-d", "NixOS", "--cd", "~"]
```

Windows Terminal does the same with no set-up: NixOS appears in its profile
list.
