# Nara

NixOS on a Hetzner Cloud CAX11 (2 Arm cores, 4 GB of memory, a 40 GB disk;
aarch64-linux) in Helsinki, in the same data centre as the storage boxes.
It is meant for Immich, with the photos on a storage box mounted over SMB,
and maybe Paperless later (see the plan on the list). For now it runs the
base system, a heartbeat to Narita's Uptime Kuma, and the storage box
mount that Immich will use.

The machine itself (disk, network, boot loader, admin account) is described
in `modules/nixos/hetzner.nix` and `modules/nixos/cloud-server.nix`, which
it shares with the Oracle hosts; `default.nix` here has the name and what
this host runs.

## Network

IPv4 by DHCP, with Hetzner's resolvers (`hetzner.nix`); IPv6 isn't
configured, because Hetzner hands it out only as a static address, and no
server's address or hardware ID is kept in this repository. On the tailnet
it is reached like every other host.

## Storage box

Immich's library is on a sub-account of the storage box that also holds
Aurora's Borg backups (`storage-box.nix`), mounted at
`/mnt/immich-library` over SMB with encryption. The sub-account has SMB
only, no access from outside Hetzner's network, and its own folder
(`immich-library`) next to, never inside, the Borg sub-accounts' folders.
Its username and password are the agenix secret
`nara/immich-library-smb.age`, a CIFS credentials file; the share's address
is made from the username, so the account name isn't in this repository.

```bash
systemctl status immich-library-mount   # mounted?
df -h /mnt/immich-library               # space on the box
```

## How it's updated

Like Ginza: CI builds the system on GitHub's Arm runner and uploads all of
it to the cache, and after every merge the host finds the new system and
activates it by itself (`custom.self-deploy`). The commands in Narita's
README ("How it's updated") work here with `nara` in place of `narita`.

## Installing

From the Mac with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere),
onto the server booted from Hetzner's NixOS ISO. It lays out the disk
(`disko.devices` in `hetzner.nix`), builds the system on the server, mostly
from the caches, copies in the SSH host key and reboots into NixOS.

The SSH host key is made beforehand and its public half put in the
secrets repository's `agenix-rules.nix`, so the system can be built with
its secrets before the host exists (`lib/hosts.nix` gets it afterwards,
with the host's Tailscale address). Its private
half goes on the server only, through nixos-anywhere's `--extra-files`.

1. In Hetzner's console: create the server (IPv4 and IPv6), attach the
   NixOS ISO for arm64 under "ISO images", and reboot it from there.
2. In the server's web console, give the ISO's `nixos` user the admin key
   from GitHub:

   ```bash
   mkdir -p ~/.ssh && curl -fsSL https://github.com/iedame.keys > ~/.ssh/authorized_keys
   ```

3. On the Mac, with `extra` a folder holding `etc/ssh/ssh_host_ed25519_key`
   and its `.pub`, and the server's public IPv4. The folders' modes are
   copied as they are, so they must be the usual 755 (and 600 for the key
   only): a 700 `etc/ssh` keeps sshd from reading the authorized keys, and
   every login is refused.

   ```bash
   nix run nixpkgs#nixos-anywhere -- --flake .#Nara --build-on remote --extra-files extra --target-host nixos@<IPv4> \
     --ssh-option IdentitiesOnly=yes --ssh-option IdentityFile=<admin public key file>
   ```

   (1Password offers its keys one by one, and the installer stops after a
   few; `-i` doesn't work with 1Password's public-key stub.)
4. Detach the ISO in Hetzner's console and reset the server, so it boots
   from the disk. Then, over the public address as `haoji`, with
   `custom.ssh-server.openToInternet = true` in `default.nix` for the
   install: `sudo tailscale up --advertise-tags=tag:server`, and approve
   the login link.
5. Afterwards: add the host's Tailscale address to `lib/hosts.nix`, remove
   `openToInternet`, and delete the local copy of the host key.
