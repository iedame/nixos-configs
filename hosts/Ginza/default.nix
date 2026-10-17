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
  # Backed up every night, encrypted, to the private R2 bucket, with a
  # weekly restore test (modules/nixos/linkding-backup.nix)
  custom.linkding-backup = {
    enable = true;
    environmentFile = config.age.secrets."backup.env".path;
  };

  # Beszel's hub: a dashboard of every host's CPU, memory, disk, network and
  # services, with history and threshold alerts. Like linkding, it listens
  # on this machine only and is published as the Tailscale Service
  # svc:beszel (https://beszel.<tailnet>.ts.net). The hosts' agents report
  # to it (README.md, "Beszel").
  services.beszel.hub.enable = true;
  custom.tailscale-services.beszel.target = "http://127.0.0.1:${toString config.services.beszel.hub.port}";

  # Atuin's sync server: shell history shared between Kawagoe, Akihabara
  # and Aurora, end-to-end encrypted by the clients
  # (modules/home-manager/atuin.nix). Its database is SQLite, so no
  # Postgres here. Published as the Tailscale Service svc:atuin
  # (README.md, "Atuin").
  services.atuin = {
    enable = true;
    database = {
      createLocally = false;
      uri = "sqlite:///var/lib/atuin/atuin.db";
    };
    # Closed: the one account exists (registered from Kawagoe). The other
    # machines log in to it with its key.
    openRegistration = false;
  };
  # The module keeps nothing on disk (it expects Postgres); the SQLite
  # database needs a directory that survives restarts
  systemd.services.atuin.serviceConfig.StateDirectory = "atuin";
  custom.tailscale-services.atuin.target = "http://127.0.0.1:${toString config.services.atuin.port}";

  # Reports this host's usage to Beszel's hub on Ginza
  # (modules/nixos/beszel-agent.nix)
  custom.beszel-agent = {
    enable = true;
    environmentFile = config.age.secrets."beszel-agent.env".path;
    # The hub is on this host
    hubUrl = "http://127.0.0.1:${toString config.services.beszel.hub.port}";
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

  # Reboots into a newly installed kernel, at 05:40 and only when there is
  # one (modules/nixos/reboot-for-kernel.nix); half an hour apart from
  # Narita (04:40), whose Uptime Kuma watches it, so the two are never down together
  custom.reboot-for-kernel = {
    enable = true;
    at = "05:40";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
