# What every Oracle Cloud host here has in common, whichever shape it is:
# imported by oracle-micro.nix (the x86 micro instances) and oracle-a1.nix
# (the Arm instance), which add what is particular to their machine.
#
# NixOS is installed over the stock Ubuntu 24.04 image (see
# hosts/Narita/README.md) and keeps that image's partitions, which is why
# the file systems below go by Ubuntu's labels. Both shapes' images use the
# same ones.
{
  modulesPath,
  ...
}:
{
  imports = [
    # virtio drivers in the initrd
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/cloudimg-rootfs";
      fsType = "ext4";
    };
    # Kernels and initrds go here (913 MB), not on the 99-106 MB EFI
    # partition
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

  # GRUB as the EFI fallback loader (EFI/BOOT/BOOTX64.EFI, or BOOTAA64.EFI
  # on Arm), which needs no entry in the instance's firmware
  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 5;
  };
  boot.loader.efi = {
    efiSysMountPoint = "/boot/efi";
    canTouchEfiVariables = false;
  };

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
