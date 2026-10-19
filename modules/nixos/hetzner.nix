{
  inputs,
  ...
}:
{
  # A Hetzner Cloud Arm server (CAX). Like oracle-a1.nix this has no enable
  # option: importing it (flake.nix, nixosModules.hetzner) is what turns it
  # on. What all cloud servers share is in cloud-server.nix.
  #
  # NixOS is installed from the Mac with nixos-anywhere onto a server booted
  # from Hetzner's NixOS ISO (hosts/Nara/README.md, "Installing"), which
  # also lays out the disk below. The network comes from DHCP, so no address
  # or hardware ID of a server is written down here.
  imports = [
    ./cloud-server.nix
    inputs.disko.nixosModules.disko
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # The server's one disk: a 512 MB EFI system partition and an ext4 root,
  # which also holds /boot and so the kernels. disko applies it at install
  # time and provides the fileSystems entries, by partition label.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot/efi";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
  # Grows into a disk enlarged by a rescale, at the next boot
  boot.growPartition = true;
  fileSystems."/".autoResize = true;

  # Hetzner's serial console on Arm is the PL011 UART
  boot.kernelParams = [
    "console=tty1"
    "console=ttyAMA0"
  ];

  # IPv4 by DHCP, with Hetzner's resolvers; IPv6 isn't configured, as
  # Hetzner hands it out only as a static address
  networking.useNetworkd = true;
  networking.useDHCP = true;

  # 4 GB of memory on a CAX11: compressed swap in RAM as a buffer
  zramSwap.enable = true;
}
