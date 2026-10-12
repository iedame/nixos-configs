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
  modulesPath,
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

  # Oracle's time server, reachable from every instance
  networking.timeServers = [ "169.254.169.254" ];

  custom.nix-core = {
    enable = true;
    # The whole system comes from this cache, built by CI (see below)
    ciCache.enable = true;
  };
  custom.locale.enable = true;
  # And activates what CI publishes after each merge, by itself
  # (modules/nixos/self-deploy.nix)
  custom.self-deploy.enable = true;

  # CI uploads everything in these hosts' systems that cache.nixos.org
  # lacks to the cache. That includes the private secrets repository, which
  # a system using an agenix secret refers to as a whole: encrypted files
  # only, and the reason the cache's bucket is private.
  #
  # agenix decrypts a host's secrets with its SSH host key (needs
  # inputs.agenix.nixosModules.default, which flake.nix adds)
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

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
  };
  security.sudo.wheelNeedsPassword = false;
  # Lets haoji hand the daemon a system that is signed by the cache's key
  nix.settings.trusted-users = [ "haoji" ];

  # SSH and Tailscale (modules/nixos/ssh-server.nix). A host being
  # converted from Ubuntu sets custom.ssh-server.openToInternet until
  # Tailscale has come back, and boot.initrd.systemd.enable = false for its
  # first boot (see hosts/Narita/README.md).
  services.tailscale.enable = true;
  custom.ssh-server.enable = true;
}
