{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.beszel-agent;
in
{
  # Beszel's agent, reporting this host's CPU, memory, disks, network,
  # temperatures, GPU and services to the hub on Ginza (hosts/Ginza,
  # "Beszel"). It connects out to the hub through the Tailscale Service
  # svc:beszel, the way the heartbeats reach Uptime Kuma, so nothing has to
  # reach the host and no port is opened here.
  #
  # The environment file holds HUB_URL (the hub's address, which names the
  # tailnet), TOKEN (a permanent universal token from the hub, which
  # registers a host the first time it connects, under its host name) and
  # KEY (the hub's public key, which the agent checks the hub against).
  options.custom.beszel-agent = {
    enable = lib.mkEnableOption "Beszel's agent, reporting to the hub on Ginza";
    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "File setting HUB_URL, TOKEN and KEY.";
    };
    hubUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://127.0.0.1:8090";
      description = ''
        The hub's address, when it differs from the environment file's: on
        the hub's own host, where it is reached locally.
      '';
    };
    extraFilesystems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/mnt/storage" ];
      description = "Mount points shown besides the root file system.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.beszel.agent = {
      enable = true;
      environmentFile = cfg.environmentFile;
      environment = {
        # Only the outgoing connection to the hub; no SSH server for the hub
        # to connect to instead
        DISABLE_SSH = "true";
      }
      # BESZEL_AGENT_-prefixed variables take precedence over the
      # environment file's
      // lib.optionalAttrs (cfg.hubUrl != null) { BESZEL_AGENT_HUB_URL = cfg.hubUrl; }
      // lib.optionalAttrs (cfg.extraFilesystems != [ ]) {
        EXTRA_FILESYSTEMS = lib.concatStringsSep "," cfg.extraFilesystems;
      };
    };
  };
}
