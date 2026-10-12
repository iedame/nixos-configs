# Oracle Cloud "Always Free" micro instance (VM.Standard.E2.1.Micro: 1 GB of
# memory, two threads of a shared CPU core).
#
# Unlike the other modules here this one has no enable option: importing it
# (flake.nix, nixosModules.oracle-micro) is what turns it on, because it
# describes the hardware and the disk of these instances.
#
# Free accounts can't import custom images, so NixOS is installed over the
# stock Ubuntu 24.04 image (see hosts/Narita/README.md) and keeps that
# image's partitions, which is why the file systems below go by Ubuntu's
# labels.
{
  lib,
  modulesPath,
  options,
  ...
}:
{
  imports = [
    # virtio drivers in the initrd
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/cloudimg-rootfs";
      fsType = "ext4";
    };
    # Kernels and initrds go here (913 MB), not on the 106 MB EFI partition
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "ext4";
    };
    "/boot/efi" = {
      device = "/dev/disk/by-label/UEFI";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  # GRUB as the EFI fallback loader (EFI/BOOT/BOOTX64.EFI), which needs no
  # entry in the instance's firmware
  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 5;
    # Boot menu on Oracle's serial console too
    extraConfig = ''
      serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
      terminal_input --append serial
      terminal_output --append serial
    '';
  };
  boot.loader.efi = {
    efiSysMountPoint = "/boot/efi";
    canTouchEfiVariables = false;
  };
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0"
  ];

  # Only for the conversion from Ubuntu: it relies on NixOS moving the old
  # system out of the way on first boot (/etc/NIXOS_LUSTRATE), which only
  # the scripted initrd implements. That initrd is deprecated and about to
  # be removed from nixpkgs, so delete this line once every host here has
  # been converted.
  boot.initrd.systemd.enable = false;

  # Oracle's time server, reachable from every instance
  networking.timeServers = [ "169.254.169.254" ];

  custom.nix-core = {
    enable = true;
    # The whole system comes from this cache, built by CI (see below)
    ciCache.enable = true;
  };
  custom.locale.enable = true;

  # CI uploads everything in these hosts' systems that cache.nixos.org
  # lacks to the public cache. Two guards follow from that. Nothing unfree
  # may end up in them: with this, adding such a package fails to evaluate
  # instead of being published.
  nixpkgs.config.allowUnfree = lib.mkForce false;
  # And no agenix: a system that uses a secret references the whole private
  # secrets repository (encrypted, but meant to stay private), which would
  # then be uploaded with it. Secrets for these hosts need another route,
  # such as a file placed on the machine by hand.
  assertions = [
    {
      assertion = !(options ? age);
      message = "Oracle micro hosts publish their system to a public cache, so they must not import agenix; see modules/nixos/oracle-micro.nix.";
    }
  ];

  # 1 GB of memory: compressed swap in RAM plus a swap file, one build at a
  # time, a small journal and no locally built NixOS manual. Evaluating a
  # NixOS configuration doesn't fit here at all, so these hosts never build
  # their own system: CI does, and the host downloads and activates it.
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048;
    }
  ];
  nix.settings.max-jobs = 1;
  services.journald.settings.Journal.SystemMaxUse = "200M";
  documentation.nixos.enable = false;

  # Administration: one account, key only, sudo without a password. There
  # is no console login to type a password at, and deploying over SSH needs
  # sudo to work unattended; the SSH key is the gate.
  users.users.haoji = {
    isNormalUser = true;
    description = "Rafael Ieda";
    extraGroups = [ "wheel" ];
    # 1Password SSH key (SHA256:u9tymbo3…), the same one that signs commits
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  # Lets haoji hand the daemon a system that is signed by the cache's key
  nix.settings.trusted-users = [ "haoji" ];

  # SSH and Tailscale (modules/nixos/ssh-server.nix)
  services.tailscale.enable = true;
  custom.ssh-server.enable = true;
}
