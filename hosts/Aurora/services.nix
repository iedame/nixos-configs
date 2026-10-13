{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Aurora's Tailscale address; services bind here so they're tailnet-only
  tailscaleIp = (import ../../lib/hosts.nix).hosts.Aurora.address;
  # Services behind Caddy live under this domain (wildcard ACME cert)
  domain = "ts.wildtonberries.com";
in

{
  # Enable Syncthing
  services.syncthing = {
    enable = true;
  };

  # Enable Caddy
  services.caddy = {
    enable = true;
    virtualHosts = {
      "immich.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:2283";
        useACMEHost = domain;
      };
      "linkding.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:9090";
        useACMEHost = domain;
      };
      "git.${domain}" = {
        extraConfig = "reverse_proxy ${tailscaleIp}:3000";
        useACMEHost = domain;
      };
      "vault.${domain}" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT} {
            header_up X-Real-IP {remote_host}
          }
        '';
        useACMEHost = domain;
      };
    };
  };

  # Caddy is only reachable over Tailscale
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      80
      443
    ];
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "git@ieda.me";
    certs = {
      ${domain} = {
        domain = "*.${domain}";
        group = "caddy";
        dnsProvider = "cloudflare";
        environmentFile = config.age.secrets."cloudflare-dns.env".path;
      };
    };
  };

  services.immich = {
    enable = true;
    host = tailscaleIp;
    port = 2283;
    mediaLocation = "/backup-pool/photos/immich/";
    machine-learning.environment = {
      HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      XDG_CACHE_HOME = "/var/cache/immich";
    };
  };

  # Allowing immich group to have mediaLocation backup permissions
  systemd.services.immich-server.serviceConfig = {
    # UMask 007 overrides the module's default (0077) for the server process,
    # ensuring new files get group read/write (660/770).
    UMask = lib.mkForce "007";
  };

  # Same for main Immich folder on reboot
  systemd.tmpfiles.settings = {
    immich = {
      # Override the setting from the immich module
      # 'e' means ensure existence and correct attributes
      "/backup-pool/photos/immich/" = {
        # Replace with your actual mediaLocation if different
        e = {
          user = config.services.immich.user;
          group = config.services.immich.group;
          mode = lib.mkForce "0750"; # Example: Owner read/write/execute, Group read/execute, Others none
        };
      };
    };
  };

  users.users.immich = {
    home = "/var/cache/immich";
  };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = tailscaleIp;
        ROOT_URL = "https://git.${domain}/";
        HTTP_PORT = 3000;
      };
      service.DISABLE_REGISTRATION = true;
      service.REQUIRE_SIGNIN_VIEW = true;
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
    };
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

  services.paperless = {
    enable = true;
    mediaDir = "/backup-pool/documents/paperless/media/";
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

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/local/vaultwarden/backup";
    # ADMIN_TOKEN etc. come from an agenix secret (secrets.nix) rather than
    # the Nix store
    environmentFile = config.age.secrets."vaultwarden.env".path;
    config = {
      # Refer to https://github.com/dani-garcia/vaultwarden/blob/main/.env.template
      DOMAIN = "https://vault.${domain}/";
      SIGNUPS_ALLOWED = false;

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };

  services.linkding = {
    # Off while the copy on Kawagoe is being tried out; the data stays in
    # /var/lib/linkding
    enable = false;
    port = 9090;
    address = tailscaleIp;
    environmentFile = config.age.secrets."linkding.env".path;
  };

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
