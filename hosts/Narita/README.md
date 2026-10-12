# Narita

NixOS on an Oracle Cloud "Always Free" micro instance (the one that was
called `helheim` under Ubuntu)
(VM.Standard.E2.1.Micro, x86_64-linux: 1 GB of memory, two threads of a
shared CPU core). It runs Uptime Kuma, reachable over Tailscale at
`http://narita:3001`.

The machine itself (disk, boot loader, memory settings, admin account) is
described in `modules/nixos/oracle-micro.nix`; `default.nix` here only has
the name and what this host runs.

## How it's updated

It can't build or even evaluate its own system: that needs more memory than
it has. Instead CI builds the system on every pull request and uploads all
of it to the public cache (`cache_all` in `.github/workflows/ci.yml`; the
configuration refuses unfree packages for that reason), and the host
downloads and activates the result. From a checkout of the merged `master`,
on any machine, including the Mac:

```bash
system=$(nix eval --raw ~/.config/nixos-configs#nixosConfigurations.Narita.config.system.build.toplevel.outPath)
ssh narita "sudo nix-env -p /nix/var/nix/profiles/system --set $system && sudo $system/bin/switch-to-configuration switch"
```

The first line only computes the system's store path (the same one CI
built, also shown in the run's summary); nothing is built locally.

## Installing

Not tried yet. A free Oracle account can't import custom images, so NixOS
is installed over the stock Ubuntu 24.04 image, following the NixOS manual's
"Installing from another Linux distribution" with one difference: the
system isn't built on the instance but downloaded from the cache. It keeps
Ubuntu's partitions. Everything else on the instance is lost.

On the Ubuntu instance, with `system` set to the store path from above:

1. Make room in memory and install Nix:

   ```bash
   sudo systemctl stop docker.socket docker 2>/dev/null
   sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
   sh <(curl -L https://nixos.org/nix/install) --daemon --yes
   ```

2. Download the system and make it the system profile:

   ```bash
   nix=/nix/var/nix/profiles/default/bin
   sudo $nix/nix-store --realise "$system" \
     --option extra-substituters https://cache.nixkeeper.com \
     --option extra-trusted-public-keys "nixos-configs-cache-1:CW5tDg3uwOBmz8C2a29loFeNcqo4sjInPjTgd0zIhOc="
   sudo $nix/nix-env -p /nix/var/nix/profiles/system --set "$system"
   ```

3. Mark the Ubuntu files to be moved to `/old-root` on the next boot,
   keeping the SSH host key and the Tailscale identity (so the host comes
   back at the same Tailscale address):

   ```bash
   sudo touch /etc/NIXOS
   printf '%s\n' etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub var/lib/tailscale | sudo tee /etc/NIXOS_LUSTRATE
   ```

4. Install NixOS's boot loader, check it, then remove Ubuntu's so the
   firmware falls back to it:

   ```bash
   sudo NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot
   sudo ls -l /boot/efi/EFI/BOOT/BOOTX64.EFI && sudo grep -c NixOS /boot/grub/grub.cfg
   sudo rm -rf /boot/efi/EFI/ubuntu
   ```

5. Reboot, and watch on the serial console (instance page → Console
   connection). Log in with `ssh narita`; if Tailscale didn't come
   back, use the public address, which `openToInternet` in `default.nix`
   keeps open for this.
6. Afterwards: delete `/old-root`, set `openToInternet = false`, and remove
   the scripted-initrd line from `modules/nixos/oracle-micro.nix`, then
   update as described above.

Oracle may reclaim Always Free instances that stay idle for a week; one
that runs something continuously, or an account upgraded to pay-as-you-go,
is not affected.
