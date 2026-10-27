{ config, pkgs, ... }:

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

  # Vaultwarden, moving here from Aurora so the passwords don't depend on
  # the desktop being on. Like linkding, it listens on this machine only and
  # is published as the Tailscale Service svc:vault
  # (https://vault.<tailnet>.ts.net). The environment file holds DOMAIN
  # (that address, which names the tailnet) and the admin token, so it is
  # an agenix secret.
  services.vaultwarden = {
    enable = true;
    environmentFile = config.age.secrets."vaultwarden.env".path;
    config = {
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };
  custom.tailscale-services.vault.target = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
  # Backed up every night, encrypted, to the private R2 bucket, with a
  # weekly restore test (modules/nixos/vaultwarden-backup.nix)
  custom.vaultwarden-backup = {
    enable = true;
    environmentFile = config.age.secrets."backup.env".path;
  };

  # Forgejo, moving here from Aurora, with its Postgres database. Like
  # linkding, it listens on this machine only and is published as the
  # Tailscale Service svc:git (https://git.<tailnet>.ts.net); that address
  # names the tailnet, so ROOT_URL comes from an agenix secret. Clones are
  # over HTTPS only.
  services.forgejo = {
    enable = true;
    # The current release, as on Aurora; the module's default is the
    # long-term one (forgejo-lts), which is older and refuses a database
    # that a newer Forgejo has already migrated (WA-5, docs/workarounds.md)
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        DISABLE_SSH = true;
      };
      service.DISABLE_REGISTRATION = true;
      service.REQUIRE_SIGNIN_VIEW = true;
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
    };
    secrets.server.ROOT_URL = config.age.secrets."forgejo-root-url".path;
  };
  custom.tailscale-services.git.target = "http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}";
  # Backed up every night, encrypted, to the private R2 bucket, with a
  # weekly restore test (modules/nixos/forgejo-backup.nix)
  custom.forgejo-backup = {
    enable = true;
    environmentFile = config.age.secrets."backup.env".path;
  };
  # The daily check and command for Postgres after a glibc update
  # (modules/nixos/postgres-collation.nix)
  custom.postgres-collation = {
    enable = true;
    databaseServices = {
      forgejo = [ "forgejo.service" ];
      postgres = [ ];
      template1 = [ ];
    };
  };

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
