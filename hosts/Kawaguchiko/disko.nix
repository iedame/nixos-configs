{ ... }:

{
  # The whole internal SSD: a 1 GiB EFI system partition and an ext4 root.
  # Applied once, at install time (see README.md); it also provides the
  # fileSystems entries, so hardware-configuration.nix has none.
  disko.devices.disk.main = {
    type = "disk";
    # By serial number rather than /dev/sda, which a USB stick can take
    device = "/dev/disk/by-id/ata-APPLE_SSD_SM0256F_S1K4NYADB95750";
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
