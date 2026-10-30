# Placeholder until the install, which writes the generated one here
# (nixos-anywhere --generate-hardware-config, see README.md)
{ lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
