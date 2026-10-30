{ ... }:

let
  # Where nayara finds the mirror: a folder in her home (default.nix makes
  # it hers)
  filesFolder = "/home/nayara/Arquivos";
  # One SSD of the mirror: one partition, all of it
  filesDisk = device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions.files = {
        size = "100%";
        content = {
          type = "mdraid";
          name = "files";
        };
      };
    };
  };
in
{
  # The three mSATA SSDs, with the BIOS's RAID off (SATA mode AHCI). The
  # first holds the system: a 1 GiB EFI system partition and an ext4 root.
  # The other two are a mirror (RAID 1) for nayara's files, which survive
  # either of them failing; the system needs no copy, as it can be rebuilt
  # from this repository. Applied once, at install time (see README.md);
  # it also provides the fileSystems entries, so hardware-configuration.nix
  # has none.
  disko.devices.disk.main = {
    type = "disk";
    # By serial number rather than /dev/sda, which a USB stick can take.
    # The three are the same model (Toshiba THNSNH128GMCT) and equally
    # healthy (SMART, 2026-10-30); this one was /dev/sda, the other two
    # /dev/sdb and /dev/sdc.
    device = "/dev/disk/by-id/ata-TOSHIBA_THNSNH128GMCT_146S107FT71Y";
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

  disko.devices.disk.files1 = filesDisk "/dev/disk/by-id/ata-TOSHIBA_THNSNH128GMCT_146S107OT71Y";
  disko.devices.disk.files2 = filesDisk "/dev/disk/by-id/ata-TOSHIBA_THNSNH128GMCT_146S107GT71Y";
  disko.devices.mdadm.files = {
    type = "mdadm";
    level = 1;
    content = {
      type = "filesystem";
      format = "ext4";
      mountpoint = filesFolder;
      # Boot doesn't wait for it: with a failed SSD the mirror comes up
      # with the other one, and without both the system still starts
      mountOptions = [
        "defaults"
        "nofail"
      ];
    };
  };
}
