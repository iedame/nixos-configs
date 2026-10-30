{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "Sendai"; # Must match nixosConfigurations.Sendai in flake.nix

  # Everything this laptop has in common with Tsukuba and Kawaguchiko:
  # desktop, browsers, automatic login and updates
  # (modules/nixos/family-laptop.nix). The battery is dead and unplugged,
  # but unlike the MacBooks' firmware this one doesn't hold the CPU back
  # without it (all cores at 3.5 GHz under load, measured at install), so
  # fullSpeedWithoutBattery stays off.
  custom.family-laptop = {
    enable = true;
    user = "nayara";
  };

  # The Wi-Fi (Intel Centrino Ultimate-N 6300, iwlwifi) needs Intel's
  # firmware, and the CPU's microcode updates come with it; the MacBooks get
  # this from their hardware profiles. The card has no Bluetooth.
  hardware.enableRedistributableFirmware = true;

  # The NVIDIA GPU (GTX 880M) is dead: error 43 in Windows, and in the
  # installer nouveau found it but its graphics engine timed out and
  # faulted as soon as anything drew on it (2026-10-30). The hardware
  # profile (flake.nix) keeps its drivers from loading and removes it at
  # boot, so it draws no power. The screen is the Intel GPU's.

  # nayara's files are on a mirror of two SSDs (disko.nix), mounted in her
  # home; the folder at its top is made hers once it is mounted
  systemd.services.nayara-files-owner = {
    description = "Give nayara the folder of her mirrored files";
    after = [ "home-nayara-Arquivos.mount" ];
    requires = [ "home-nayara-Arquivos.mount" ];
    wantedBy = [ "home-nayara-Arquivos.mount" ];
    serviceConfig.Type = "oneshot";
    script = "chown nayara: /home/nayara/Arquivos && chmod 700 /home/nayara/Arquivos";
  };
  # A failing SSD, or a mirror missing one, fails a check that the
  # heartbeat reports (modules/nixos/disk-health.nix). These SSDs are from
  # 2014. mdadm itself writes its events to the journal.
  custom.disk-health.enable = true;
  boot.swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";

  # The built-in keyboard is unplugged (dead keys, and keys pressing by
  # themselves); a USB keyboard, Brazilian ABNT2, is used instead
  custom.plasma.keyboardLayout = "br";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
