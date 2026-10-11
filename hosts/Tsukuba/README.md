# Tsukuba

NixOS on a 13" MacBook Pro from 2011 (MacBookPro8,1, x86_64-linux): a family
laptop for browsing and documents, in Brazilian Portuguese, administered
remotely.

## How it's kept up to date

Nobody runs `update` here. Every day (or at the next start, if it was off)
`system.autoUpgrade` builds `github:iedame/nixos-configs#Tsukuba` from
`master` and makes it the default for the next boot, so nothing changes under
a running session. A change reaches the laptop by being merged; CI builds
this host on every pull request first.

- State of the last run: `systemctl status nixos-upgrade`
- Apply something right away, over Tailscale:
  `ssh haoji@tsukuba`, then `sudo nixos-rebuild switch --flake github:iedame/nixos-configs#Tsukuba --refresh`
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

- **Wi-Fi**: a Broadcom BCM4331, driven by the kernel's `b43` driver with
  downloaded firmware (`networking.enableB43Firmware`, set by the hardware
  profile). If it proves unreliable, the alternative is Broadcom's own
  driver: `boot.kernelModules = [ "wl" ]`,
  `boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ]`,
  `networking.enableB43Firmware = false`, and the package allowed through
  `custom.nix-core.permittedInsecurePackages`.
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

Not tried yet. It erases the laptop's disk, so copy the home directory
somewhere first.

1. Boot the laptop from a NixOS installer USB stick (hold Option at
   power-on), connect an Ethernet cable, set a password for the installer's
   user with `passwd`, and note the address shown by `ip a`.
2. From Aurora, partition, generate the hardware settings and install,
   without rebooting yet:

   ```bash
   cd ~/.config/nixos-configs
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#Tsukuba \
     --generate-hardware-config nixos-generate-config ./hosts/Tsukuba/hardware-configuration.nix \
     --phases kexec,disko,install \
     --target-host nixos@<address>
   ```

3. Set the two passwords in the installed system, then reboot:

   ```bash
   ssh root@<address> nixos-enter --root /mnt -c "'passwd haoji'"
   ssh root@<address> nixos-enter --root /mnt -c "'passwd yuki'"
   ssh root@<address> reboot
   ```

4. Log in on the laptop as `haoji`, join the tailnet with
   `sudo tailscale up`, and tag the device in the admin console.
5. Commit the generated `hardware-configuration.nix` and merge it, so that
   `master` describes the machine as installed.
