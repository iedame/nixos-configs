# Tsukuba

NixOS on a 13" MacBook Pro from 2011 (MacBookPro8,1, x86_64-linux): a family
laptop for browsing and documents, in Brazilian Portuguese, administered
remotely.

## How it's kept up to date

Nobody runs `update` here. Once a week (or at the next start, if it was off)
`system.autoUpgrade` builds `github:iedame/nixos-configs#Tsukuba` from
`master` and makes it the default for the next boot, so nothing changes under
a running session. A change reaches the laptop by being merged; CI builds
this host on every pull request first.

- State of the last run: `systemctl status nixos-upgrade`
- Apply something right away, over Tailscale:
  `ssh tsukuba` (an alias from `modules/home-manager/ssh.nix`), then
  `sudo nixos-rebuild switch --flake github:iedame/nixos-configs#Tsukuba --refresh`
- Undo a bad update: pick the previous generation in the boot menu (hold
  Option at power-on for the Mac's boot picker if it doesn't show).

This host uses neither agenix nor home-manager, so it evaluates without
access to the private `secrets` input. Keep it that way, or the automatic
update stops working.

## Layout

| File | What's in it |
|---|---|
| `default.nix` | Boot, locale, Plasma, apps, Flatpak, Tailscale and SSH, automatic updates |
| `users.nix` | `yuki` (everyday use, no administrator rights) and `haoji` (administration) |
| `disko.nix` | Disk layout, applied at install time |
| `hardware-configuration.nix` | Generated hardware settings |

The model-specific settings (Wi-Fi firmware, fan control, Sandy Bridge
graphics, SSD) come from the `apple-macbook-pro-8-1` profile of
[nixos-hardware](https://github.com/NixOS/nixos-hardware), added in
`flake.nix`.

## Host-specific pieces

- **Wi-Fi**: a Broadcom BCM4331, driven by Broadcom's own `wl` driver
  (`broadcom_sta`). The hardware profile's choice, the kernel's `b43` with
  downloaded firmware, works but has no 802.11n for this card and managed
  14 Mbit/s. `wl` is unmaintained and marked insecure in nixpkgs, so
  `default.nix` allows it by name. CI builds the module and uploads it to
  the cache, so kernel updates don't compile it on the laptop.
- **Keyboard**: physically a US (ANSI) one, so the layout is US
  International: keys type what they show, accents are dead keys.
- **Battery**: dead, so none is detected; the laptop only runs plugged in.
- **Browsing history**: neither Firefox nor Chrome records visited pages;
  logins, cookies and bookmarks are kept. Set by policy in `default.nix`,
  so it can't be switched back on in the browser.
- **Tuned for an old CPU**: ad blockers in both browsers (uBlock Origin,
  uBlock Origin Lite), the CPU always at full speed, no KDE mail suite, no
  file indexing, no desktop animations, a one-second boot menu.
- **Video**: the GPU decodes H.264 only, so Firefox and Chrome are set up
  to decode on the GPU and to ask YouTube for H.264 (see `default.nix`).
- **Apps**: Firefox, Chrome, OnlyOffice and VLC come from this config.
  Anything else can be installed from Discover through Flatpak, without
  administrator rights.
- **No passwords in daily use**: the laptop goes straight to `yuki`'s
  desktop, and the screen doesn't lock after sleep or a closed lid, so
  anyone who opens it is in. KWallet is disabled so it doesn't ask for a
  password of its own; browsers keep saved passwords in their own store.
- **Access**: SSH is reachable only over Tailscale, with my key, as `haoji`.
- **Passwords** are set on the machine with `passwd` and are not in this
  repository.

## Installing

This is how it was installed (from Kawagoe, about 25 minutes). It erases the
laptop's disk, so copy the home directory somewhere first.

1. Boot the laptop from a NixOS minimal installer USB stick (hold Option at
   power-on, choose "EFI Boot"), connect an Ethernet cable, set a password
   for the installer's user with `passwd`, and note the address shown by
   `ip a`.
2. Add an SSH key to the installer session, for step 4 (`key.pub` holds the
   public key authorised in `users.nix`):

   ```bash
   ssh-copy-id -f -i key.pub -o IdentityAgent=none nixos@<address>
   ```

3. Partition, generate the hardware settings and install, without rebooting
   yet. `--build-on remote` makes the laptop download and build its own
   system, straight onto its disk, so this works from a Mac too:

   ```bash
   cd ~/.config/nixos-configs
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#Tsukuba \
     --build-on remote \
     --generate-hardware-config nixos-generate-config ./hosts/Tsukuba/hardware-configuration.nix \
     --phases kexec,disko,install \
     --ssh-option IdentityAgent=none \
     --target-host nixos@<address>
   ```

4. Set the two passwords in the installed system, then remove the stick and
   reboot:

   ```bash
   ssh -t -o IdentitiesOnly=yes -i key.pub nixos@<address> "sudo nixos-enter --root /mnt -c 'passwd haoji'"
   ssh -t -o IdentitiesOnly=yes -i key.pub nixos@<address> "sudo nixos-enter --root /mnt -c 'passwd yuki'"
   ```

5. On the laptop, open a terminal, become `haoji` with `su - haoji`, join
   the tailnet with `sudo tailscale up`, and tag the device in the admin
   console.
6. Run `nix fmt`, then commit the generated `hardware-configuration.nix` and
   merge it, so that `master` describes the machine as installed.
