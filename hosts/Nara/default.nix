{ config, ... }:

{
  imports = [ ./secrets.nix ];

  # Everything about the machine itself (disk, network, boot loader, admin
  # account) is in modules/nixos/hetzner.nix and cloud-server.nix; this file
  # has the name and what this host runs.
  networking.hostName = "Nara"; # Must match nixosConfigurations.Nara in flake.nix

  # Reports this host's usage to Beszel's hub on Ginza
  # (modules/nixos/beszel-agent.nix)
  custom.beszel-agent = {
    enable = true;
    environmentFile = config.age.secrets."beszel-agent.env".path;
  };

  # A `notify` command that sends a Telegram message
  # (modules/nixos/notify.nix); used to announce the reboots below
  custom.notify = {
    enable = true;
    environmentFile = config.age.secrets."telegram.env".path;
  };

  # Reboots into a newly installed kernel, at 06:10 and only when there is
  # one (modules/nixos/reboot-for-kernel.nix), after the Oracle hosts
  custom.reboot-for-kernel = {
    enable = true;
    at = "06:10";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
