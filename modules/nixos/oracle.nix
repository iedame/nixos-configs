# What every Oracle Cloud host here has in common, whichever shape it is:
# imported by oracle-micro.nix (the x86 micro instances) and oracle-a1.nix
# (the Arm instance), which add what is particular to their machine. What
# all cloud servers share, Oracle's or not, is in cloud-server.nix.
#
# NixOS is installed over the stock Ubuntu 24.04 image (see
# hosts/Narita/README.md) and keeps that image's partitions, which is why
# the file systems below go by Ubuntu's labels. Both shapes' images use the
# same ones.
{
  imports = [ ./cloud-server.nix ];

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

  # Oracle's time server, reachable from every instance
  networking.timeServers = [ "169.254.169.254" ];
}
