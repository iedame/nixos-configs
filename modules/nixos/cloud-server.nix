# What every cloud server here has in common, whoever hosts it: imported by
# oracle.nix (Oracle Cloud) and hetzner.nix (Hetzner Cloud), which add the
# provider's disk layout, network and time server.
#
# These are virtual machines installed over the provider's stock Ubuntu
# image (see hosts/Narita/README.md), administered over SSH and Tailscale,
# that never build their own system: CI builds it and the host downloads and
# activates it.
{
  modulesPath,
  ...
}:
{
  imports = [
    # virtio drivers in the initrd
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

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
