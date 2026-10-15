# Oracle Cloud "Always Free" micro instance (VM.Standard.E2.1.Micro: 1 GB of
# memory, two threads of a shared CPU core).
#
# Unlike the other modules here this one has no enable option: importing it
# (flake.nix, nixosModules.oracle-micro) is what turns it on, because it
# describes the hardware and the disk of these instances. What all Oracle
# hosts share is in oracle.nix.
{
  imports = [ ./oracle.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Boot menu on Oracle's serial console too
  boot.loader.grub.extraConfig = ''
    serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
    terminal_input --append serial
    terminal_output --append serial
  '';
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0"
  ];

  # 1 GB of memory: compressed swap in RAM plus a swap file, one build at a
  # time, and a small journal and no locally built NixOS manual
  # (oracle.nix). Evaluating a NixOS configuration doesn't fit here at all,
  # so these hosts never build their own system: CI does, and the host
  # downloads and activates it.
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048;
    }
  ];
  nix.settings.max-jobs = 1;
}
