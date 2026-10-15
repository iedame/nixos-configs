{ config, ... }:

{
  imports = [ ./secrets.nix ];

  # Everything about the machine itself is in modules/nixos/oracle-a1.nix
  # and oracle.nix; this file has the name and what this host runs.
  networking.hostName = "Ginza"; # Must match nixosConfigurations.Ginza in flake.nix

  # Bookmarks, moved here from the Mac. It listens on this machine only and
  # is published on the tailnet as the Tailscale Service svc:linkding, with
  # its own name and HTTPS certificate: https://linkding.<tailnet>.ts.net
  # (modules/nixos/tailscale-services.nix). The environment file holds the
  # settings that name the tailnet, so it is an agenix secret.
  services.linkding = {
    enable = true;
    environmentFile = config.age.secrets."linkding.env".path;
  };
  custom.tailscale-services.linkding.target = "http://127.0.0.1:${toString config.services.linkding.port}";

  # Reports this host's health to Narita's Uptime Kuma, which alerts if a
  # unit fails here or the reports stop (modules/nixos/heartbeat.nix). The
  # monitor's push URL is an agenix secret (secrets.nix).
  custom.heartbeat = {
    enable = true;
    urlFile = config.age.secrets."heartbeat-url".path;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
