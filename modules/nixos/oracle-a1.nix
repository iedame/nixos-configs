# Oracle Cloud Ampere A1 instance (VM.Standard.A1.Flex, the whole Always
# Free allowance: 4 Arm cores and 24 GB of memory).
#
# Like oracle-micro.nix this has no enable option: importing it (flake.nix,
# nixosModules.oracle-a1) is what turns it on. What all Oracle hosts share
# is in oracle.nix.
#
# It has the memory to build its own system, but it is set up like the
# micro instances anyway: CI builds the system, on an Arm runner, and the
# host downloads and activates it. Evaluating the configuration needs the
# private secrets repository, which this host has no access to.
{
  imports = [ ./oracle.nix ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # Oracle's serial console on Arm is the PL011 UART
  boot.kernelParams = [
    "console=tty1"
    "console=ttyAMA0"
  ];
}
