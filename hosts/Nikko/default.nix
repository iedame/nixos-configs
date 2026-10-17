{ config, ... }:

{
  imports = [ ./secrets.nix ];

  # Everything about the machine itself is in modules/nixos/oracle-micro.nix
  networking.hostName = "Nikko"; # Must match nixosConfigurations.Nikko in flake.nix

  # Tailscale exit node: other devices on the tailnet can route their
  # internet traffic through this server. Needs packet forwarding, which
  # "server" turns on; the flag makes Tailscale offer the node (it still
  # has to be allowed once in the admin console).
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # Uptime monitoring. It listens on this machine only and is published
  # on the tailnet as a Tailscale Service, with its own name and HTTPS
  # certificate: https://kuma-nikko.<tailnet>.ts.net
  # (modules/nixos/tailscale-services.nix). Narita runs one too, and each
  # watches the other.
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
    };
  };
  custom.tailscale-services."kuma-nikko".target = "http://127.0.0.1:3001";
  # Its database is backed up every night, encrypted, to a private R2
  # bucket (modules/nixos/uptime-kuma-backup.nix)
  custom.uptime-kuma-backup = {
    enable = true;
    environmentFile = config.age.secrets."backup.env".path;
  };

  # Reports this host's usage to Beszel's hub on Ginza
  # (modules/nixos/beszel-agent.nix)
  custom.beszel-agent = {
    enable = true;
    environmentFile = config.age.secrets."beszel-agent.env".path;
  };

  # Reports this host's health to Narita's Uptime Kuma, which alerts if a
  # unit fails here or the reports stop (modules/nixos/heartbeat.nix). The
  # monitor's push URL is an agenix secret (secrets.nix).
  custom.heartbeat = {
    enable = true;
    urlFile = config.age.secrets."heartbeat-url".path;
  };

  # A `notify` command that sends a Telegram message
  # (modules/nixos/notify.nix); used to announce the reboots below
  custom.notify = {
    enable = true;
    environmentFile = config.age.secrets."telegram.env".path;
  };

  # Reboots into a newly installed kernel, at 05:10 and only when there is
  # one (modules/nixos/reboot-for-kernel.nix); half an hour apart from
  # Narita (04:40), which watches it, so the two are never down together
  custom.reboot-for-kernel = {
    enable = true;
    at = "05:10";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
