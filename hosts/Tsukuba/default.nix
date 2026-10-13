{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "Tsukuba"; # Must match nixosConfigurations.Tsukuba in flake.nix

  # Everything this laptop has in common with the other one of its kind:
  # desktop, browsers, automatic login and updates
  # (modules/nixos/family-laptop.nix)
  custom.family-laptop = {
    enable = true;
    # Wi-Fi (Broadcom BCM4331): Broadcom's own driver instead of the
    # kernel's b43, which the hardware profile selects. b43 has no 802.11n
    # support for this card and measured 14 Mbit/s here.
    broadcomWl = true;
    # The battery is dead: without this the CPU is held at 798 MHz
    fullSpeedWithoutBattery = true;
  };
  networking.enableB43Firmware = false;

  # The hardware profile (flake.nix) assumes the PCIe camera of later
  # MacBooks and would build its unfree driver; this model's is plain USB
  hardware.facetimehd.enable = false;

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
