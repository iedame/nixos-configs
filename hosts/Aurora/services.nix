{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable Syncthing
  services.syncthing = {
    enable = true;
  };

  # Immich moved to Nara (2026-10-19). Only its machine learning runs
  # here, for Nara; its photos are backed up by the mirror on the external
  # pool (immich-mirror.nix). No database, no server.
  services.immich = {
    enable = true;
    database.enable = false;
    redis.enable = false;
    machine-learning.environment = {
      HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      XDG_CACHE_HOME = "/var/cache/immich";
      # Serves Nara's Immich, over Tailscale (hosts/Nara/immich.nix). It
      # has no login of its own: the firewall opens its port on tailscale0
      # only (below), and the tailnet's access rules decide who reaches it.
      IMMICH_HOST = lib.mkForce "0.0.0.0";
      # Idle connections stay open longer than Nara's client keeps them
      # (about 4 s). With the default 2 s, a request sent on a connection
      # Aurora was just closing failed as "other side closed", more often
      # with the ~230 ms between Helsinki and Aurora.
      MACHINE_LEARNING_HTTP_KEEPALIVE_TIMEOUT_S = "30";
    };
  };
  systemd.services.immich-server.enable = false;

  # Immich's machine learning for Nara is only reachable over Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3003 ];

  users.users.immich = {
    home = "/var/cache/immich";
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  services.seerr = {
    enable = true;
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
  };

  services.bazarr = {
    enable = true;
    openFirewall = false;
  };

  # Paperless stays here, at home, rather than on a cloud server: the
  # documents are the most private data on this machine. It listens on this
  # machine only and is published as the Tailscale Service svc:paperless
  # (https://paperless.<tailnet>.ts.net, modules/nixos/tailscale-services.nix),
  # reachable from the other devices while this one is on. That address
  # names the tailnet, so PAPERLESS_URL is in an agenix secret.
  services.paperless = {
    enable = true;
    mediaDir = "/backup-pool/documents/paperless/media/";
    environmentFile = config.age.secrets."paperless.env".path;
    settings = {
      PAPERLESS_OCR_LANGUAGE = "por+eng";
    };
    # Paperless's own export: every document with its metadata, in a form
    # a fresh install can import again. No timer: the backup job starts it
    # before each run (backup.nix), so the export is never older than the
    # backup.
    exporter = {
      enable = true;
      onCalendar = null;
    };
  };

  custom.tailscale-services.paperless.target = "http://127.0.0.1:${toString config.services.paperless.port}";

  virtualisation = {
    docker.enable = false;
    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
      # Periodically prune Podman resources
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    oci-containers = {
      backend = "podman";
    };
  };
}
