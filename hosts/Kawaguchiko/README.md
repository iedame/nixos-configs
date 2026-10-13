# Kawaguchiko

NixOS on a 13" Retina MacBook Pro from late 2013 (MacBookPro11,1,
x86_64-linux): a second family laptop for browsing, set up exactly like
[Tsukuba](../Tsukuba/README.md). That README describes how these laptops
are kept up to date, used and administered; this one only lists what
differs.

## Layout

| File | What's in it |
|---|---|
| `default.nix` | What is specific to this laptop: name, Wi-Fi driver, the weak battery, keyboard |
| `disko.nix` | Disk layout: the partitions are found by the names it gives them |
| `hardware-configuration.nix` | Hardware settings |

Everything else is in `modules/nixos/family-laptop.nix`, shared with
Tsukuba. The model-specific settings (fan control, Haswell graphics, SSD)
come from the `apple-macbook-pro-11-1` profile of
[nixos-hardware](https://github.com/NixOS/nixos-hardware), added in
`flake.nix`.

## What differs from Tsukuba

- **Wi-Fi**: a Broadcom BCM4360. Only Broadcom's own `wl` driver supports
  it, the same one Tsukuba uses by choice. The NixOS installer doesn't
  include it and this model has no Ethernet port, which is why it was
  converted in place (see below).
- **Battery**: holds a few minutes. The `disable-bd-prochot` service is
  enabled here too, so that the firmware doesn't hold the CPU back: all
  cores stay at 2.9 GHz under load.
- **Camera**: a PCIe FaceTime HD, driven by the `facetimehd` kernel module
  with Apple's firmware. Tsukuba's camera is a plain USB one and needs
  neither. CI builds the module and uploads it to the cache. The driver
  logs one missing file at boot (`1871_01XX.dat`, sensor calibration); it
  is optional.
- **Screen**: a Retina panel (2560x1600). Plasma chooses a scale for it by
  itself; change it in System Settings if things look too small or large.
- **Video**: the GPU decodes H.264 but not VP9 or AV1, like Tsukuba's, so
  the same browser settings apply.

## Installing

It was converted in place from CachyOS, over SSH, the way Narita and Nikko
were converted from Ubuntu ([Narita's README](../Narita/README.md) has the
method in full). The home folders start empty; the CachyOS ones are in
`/old-root` until that is deleted. What was specific to this laptop:

1. On CachyOS: start `sshd`, install Nix, and write
   `hardware-configuration.nix` with `nixos-generate-config`.
2. `disko.nix` finds the partitions by name, so the two existing ones were
   given the names disko would have used. CachyOS already had a 2 GB EFI
   partition and an ext4 root, so nothing was resized or formatted:

   ```bash
   sudo sfdisk --part-label /dev/sda 1 disk-main-ESP
   sudo sfdisk --part-label /dev/sda 2 disk-main-root
   ```

3. Put the cache token in `/root/.aws/credentials` (see "Binary cache" in
   the main README) and build the system on the laptop, with one setting
   added for the conversion only: NixOS moves the old system aside on first
   boot (`/etc/NIXOS_LUSTRATE`), and only the scripted initrd does that.

   ```nix
   boot.initrd.systemd.enable = false;
   ```

4. Keep the passwords, the SSH host key and the cache token across the
   reboot, then install the boot loader and reboot:

   ```bash
   sudo nix-env -p /nix/var/nix/profiles/system --set <the built system>
   sudo touch /etc/NIXOS
   printf '%s\n' etc/shadow etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub root/.aws/credentials | sudo tee /etc/NIXOS_LUSTRATE
   sudo NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot
   sudo reboot
   ```

   Keeping `/etc/shadow` carries over the passwords of `yuki` and `haoji`,
   which exist under the same names here.
5. Afterwards: connect the Wi-Fi, `sudo tailscale up` and tag the machine,
   rebuild once from `master` to drop the conversion setting, and delete
   `/old-root`.

For a clean install from a USB stick instead, follow "Installing" in
Tsukuba's README with `Kawaguchiko` in place of `Tsukuba`. It erases the
disk, and needs a USB or Thunderbolt Ethernet adapter or a phone's USB
tethering, because the installer can't use this laptop's Wi-Fi.
