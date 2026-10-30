# Sendai

NixOS on an MSI GT70 2PE (Dominator Pro) from 2014 (x86_64-linux): a
third family laptop, for studying, set up like
[Tsukuba](../Tsukuba/README.md). That README describes how these laptops
are kept up to date, used and administered; this one only lists what
differs. The everyday account is `nayara`.

## Layout

| File | What's in it |
|---|---|
| `default.nix` | What is specific to this laptop: name, account, keyboard |
| `disko.nix` | Disk layout, applied at install time |
| `hardware-configuration.nix` | Generated hardware settings |

Everything else is in `modules/nixos/family-laptop.nix`, shared with
Tsukuba and Kawaguchiko. nixos-hardware has no profile for this model, so
`flake.nix` adds the parts that fit it: Haswell CPU and graphics, laptop,
SSD, and `common-gpu-nvidia-disable`.

## What differs from Tsukuba

- **NVIDIA GPU**: a GTX 880M, dead (error 43 in Windows). Its drivers are
  kept from loading and the card is removed at boot, so it draws no power;
  the screen runs on the Intel GPU. If it ever shows up again in `lspci`
  or warms the laptop, check that profile first.
- **Keyboard**: the built-in one is unplugged (dead keys, and keys that
  pressed themselves). A USB keyboard is used, Brazilian ABNT2, which is
  the layout set here. The touchpad works.
- **Disks**: three mSATA SSDs, which the BIOS combined into one RAID 0
  volume under Windows. RAID is off (SATA mode AHCI), and NixOS is on one
  SSD; the other two are unused. The 1 TB hard disk was removed.
- **Wi-Fi and Ethernet**: Killer (Qualcomm Atheros) cards with mainline
  drivers, so nothing like Tsukuba's Broadcom setup.
- **Video**: like the others, the Intel GPU decodes H.264 only, and the
  same browser settings apply.
- **Battery**: dead and unplugged, so it runs on its power adapter only,
  and a power cut switches it off at once (unsaved work is lost; an
  interrupted update is simply retried). Whether the firmware then holds
  the CPU back, as on the MacBooks, is checked at install.

## Installing

As for [Tsukuba](../Tsukuba/README.md#installing), from Kawagoe with
nixos-anywhere, with these differences:

1. In the BIOS (Delete at power-on): set the SATA mode from RAID to AHCI.
   This dissolves the RAID 0 volume and with it Windows. Keep secure boot
   off.
2. Boot the NixOS installer from a USB stick, with a USB keyboard and an
   Ethernet cable, then `passwd` and `ip a` as for Tsukuba.
3. Read the SSDs' names (`ls -l /dev/disk/by-id/ | grep -v part`) and put
   the one to install on in `disko.nix`.
4. Install with `--flake .#Sendai` and
   `--generate-hardware-config nixos-generate-config ./hosts/Sendai/hardware-configuration.nix`,
   then set the two passwords (`haoji`, `nayara`).
5. After the first boot: join the tailnet, and add the address and host
   key to `lib/hosts.nix`. Put the files the repository can't hold in
   place by hand: the cache token in `/root/.aws/credentials` (the main
   README, "Binary cache"), the heartbeat URL and Beszel's settings
   (Tsukuba's README, "Health reports" and "Beszel").
6. Merge, so that the daily update finds `Sendai` on `master`.
