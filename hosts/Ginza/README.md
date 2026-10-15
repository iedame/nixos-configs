# Ginza

NixOS on Oracle Cloud's Always Free Ampere A1 instance (VM.Standard.A1.Flex,
aarch64-linux: 4 Arm cores and 24 GB of memory, the whole free A1
allowance). It runs:

- **linkding**, the bookmark manager, moved here from the Mac:
  `https://linkding.<tailnet>.ts.net`, the Tailscale Service `svc:linkding`.
- **The tailnet's DNS server** (Blocky): ordinary lookups from the tailnet's
  devices, with ads and trackers blocked, sent on to Quad9 and Cloudflare
  over HTTPS.

The machine itself (disk, boot loader, admin account) is described in
`modules/nixos/oracle-a1.nix` and `modules/nixos/oracle.nix`, which it
shares with Narita and Nikko; `default.nix` here has the name and what this
host runs.

## How it's updated

Like Narita and Nikko: CI builds the system (on GitHub's Arm runner) and
uploads all of it to the cache, and after every merge the host finds the
new system and activates it by itself (`custom.self-deploy`). The commands
in Narita's README ("How it's updated") work here with `ginza` in place of
`narita`.

## The tailnet's DNS

In the Tailscale admin console, DNS:

1. Add a global nameserver: this host's Tailscale address.
2. Turn on "Override local DNS", so devices use it instead of their
   network's resolver.

Names on the tailnet itself (MagicDNS) keep working: each device's
Tailscale answers those and sends everything else here. This host doesn't
use itself, and neither do Narita and Nikko (`--accept-dns=false` in
`modules/nixos/oracle.nix`), so it keeps resolving and updating while
Blocky is down, and their monitoring doesn't depend on it. The tailnet's
other devices do: if Ginza is down, their lookups fail until it is back, or
until "Override local DNS" is turned off. A device can opt out with
Tailscale's own switch ("Use Tailscale DNS settings").

To see what it does: `ssh ginza journalctl -u blocky -n 20 --no-pager`.
A blocked name answers `0.0.0.0`:
`dig @<Ginza's Tailscale address> doubleclick.net`.

## linkding

The service is published by `custom.tailscale-services` in `default.nix`.
Once, in the admin console: approve this host for `svc:linkding` (the
service already exists from the Mac). The tags allowed to reach it don't
change.

Its data is in `/var/lib/linkding`: the SQLite database, favicons and
previews. It moved from the Mac's `~/.local/share/linkding` (same linkding
version, 1.47.0) by copying that folder over with linkding stopped on both
sides.

## Installing

Converted in place from Oracle's stock Ubuntu 24.04 image for Arm, the
same way as Narita (see "Installing" in Narita's README), with these
differences:

- **No swap file is needed** for the conversion: there is enough memory.
- **The image already has `curl` and `xz`.**
- **The boot loader file is `EFI/BOOT/BOOTAA64.EFI`**, not `BOOTX64.EFI`,
  and Ubuntu's firmware entry is `0005` (`efibootmgr` shows it).
- **The SSH host key is kept**, so the key in the secrets repo's rules and
  in `lib/hosts.nix` stays valid.
- **SSH from the internet is closed** in Oracle's security list. For the
  conversion, an ingress rule allowed port 22 from one address only (the
  one doing the conversion), removed again once Tailscale was back.
