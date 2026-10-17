{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.beszel-agent;
  dataDir = "/var/db/beszel-agent";
in
{
  # The macOS counterpart of modules/nixos/beszel-agent.nix: Beszel's agent,
  # reporting this Mac's CPU, memory, disks, network and temperatures to the
  # hub on Ginza. nix-darwin has no module for it, so this is a launchd
  # daemon of its own. It connects out to the hub through the Tailscale
  # Service svc:beszel; nothing listens here.
  #
  # The environment file is the one the Linux hosts use (HUB_URL, TOKEN and
  # KEY); launchd can't read one, so the script loads it.
  options.custom.beszel-agent = {
    enable = lib.mkEnableOption "Beszel's agent, reporting to the hub on Ginza";
    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "File setting HUB_URL, TOKEN and KEY.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.beszel-agent = {
      # sysctl, ioreg and the like, which the agent reads the system with
      path = [
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
      script = ''
        # Missing until agenix has run, right after a first switch; launchd
        # starts this again shortly
        if [ ! -r ${lib.escapeShellArg cfg.environmentFile} ]; then
          echo "$(date '+%F %T') ${cfg.environmentFile} not readable yet"
          exit 1
        fi
        set -a
        . ${lib.escapeShellArg cfg.environmentFile}
        set +a
        # Only the outgoing connection to the hub; no SSH server for the hub
        # to connect to instead
        export DISABLE_SSH=true
        # Where the agent keeps its fingerprint, which identifies it to the
        # hub across restarts
        export DATA_DIR=${dataDir}
        mkdir -p ${dataDir}
        chmod 700 ${dataDir}
        exec ${lib.getExe' pkgs.beszel "beszel-agent"}
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        # Seconds between restarts when it exits
        ThrottleInterval = 30;
        StandardOutPath = "/var/log/beszel-agent.log";
        StandardErrorPath = "/var/log/beszel-agent.log";
      };
    };
  };
}
