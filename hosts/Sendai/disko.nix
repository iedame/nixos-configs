{ ... }:

{
  # One of the three mSATA SSDs, with the BIOS's RAID off (SATA mode AHCI):
  # a 1 GiB EFI system partition and an ext4 root. The other two are left
  # unused. Applied once, at install time (see README.md); it also provides
  # the fileSystems entries, so hardware-configuration.nix has none.
  disko.devices.disk.main = {
    type = "disk";
    # By serial number rather than /dev/sda, which a USB stick can take.
    # TODO: the SSD's /dev/disk/by-id name, read from the installer.
    device = "/dev/disk/by-id/TODO";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
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
}
