{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "Sendai"; # Must match nixosConfigurations.Sendai in flake.nix

  # Everything this laptop has in common with Tsukuba and Kawaguchiko:
  # desktop, browsers, automatic login and updates
  # (modules/nixos/family-laptop.nix). Its Wi-Fi has a mainline driver.
  custom.family-laptop = {
    enable = true;
    user = "nayara";
    # TODO at install: the battery is dead and unplugged. If the firmware
    # then holds the CPU at its lowest speed, as the MacBooks' does, turn on
    # fullSpeedWithoutBattery.
  };

  # The NVIDIA GPU (GTX 880M) is dead (error 43 in Windows): the hardware
  # profile (flake.nix) keeps its drivers from loading and removes it at
  # boot, so it draws no power. The screen is the Intel GPU's.

  # The built-in keyboard is unplugged (dead keys, and keys pressing by
  # themselves); a USB keyboard, Brazilian ABNT2, is used instead
  custom.plasma.keyboardLayout = "br";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
