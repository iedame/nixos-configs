{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "Kawaguchiko"; # Must match nixosConfigurations.Kawaguchiko in flake.nix

  # Everything this laptop has in common with Tsukuba: desktop, browsers,
  # automatic login and updates (modules/nixos/family-laptop.nix)
  custom.family-laptop = {
    enable = true;
    # Wi-Fi (Broadcom BCM4360): only Broadcom's own driver supports it
    broadcomWl = true;
    # The battery lasts a few minutes. MacBooks hold the CPU back when the
    # battery can't help the power adapter, so this lifts that, as on
    # Tsukuba
    fullSpeedWithoutBattery = true;
  };

  # The camera, a PCIe FaceTime HD, works through the facetimehd driver and
  # Apple's firmware, which the hardware profile (flake.nix) switches on.
  # CI builds the driver and uploads it to the cache, so kernel updates
  # don't compile it here.

  # The keyboard is physically a US one: US International types what the
  # keys show and makes accents with dead keys (' then c gives ç)
  custom.plasma = {
    keyboardLayout = "us";
    keyboardVariant = "intl";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
