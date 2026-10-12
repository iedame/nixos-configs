{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.self-deploy;
  cache = config.custom.nix-core.ciCache;
  host = config.networking.hostName;
  credentials = "/root/.aws/credentials";
in
{
  # Lets a host that can't build or evaluate its own system keep itself up
  # to date. After every merge CI builds the system, uploads it to the cache
  # and writes its store path to the object deploy/<host name> in the
  # cache's bucket (.github/workflows/ci.yml). A timer here reads that
  # object and, when it names a system other than the running one,
  # downloads and activates it.
  #
  # Only CI's master run writes the object, so merging is what deploys. The
  # object isn't signed, but the system it names is: Nix only accepts a
  # download carrying the cache's signature, and anything that isn't a
  # system of this host is refused below.
  #
  # A failed update leaves this unit failed, which the heartbeat
  # (heartbeat.nix) reports. `systemctl stop self-deploy.timer` holds the
  # host at its current system, for instance after a manual rollback, until
  # the timer is started again or the host reboots.
  options.custom.self-deploy = {
    enable = lib.mkEnableOption "activating the system CI last published for this host";
    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "When to look for a new system, as a systemd calendar expression.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.custom.nix-core.ciCache.enable;
        message = "custom.self-deploy downloads the system from the CI cache: enable custom.nix-core.ciCache.";
      }
    ];

    systemd.services.self-deploy = {
      description = "Activate the system CI last published for this host";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Activating a system that changes this unit would otherwise stop it
      # in the middle of the activation it is running
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;
      environment = config.nix.envVars // {
        HOME = "/root";
      };
      path = [
        config.nix.package
        pkgs.coreutils
        pkgs.curl
        pkgs.gawk
        pkgs.gnugrep
      ];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "self-deploy";
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        set -eu

        # The cache's read token (see README.md, "Binary cache"), passed to
        # curl on its standard input so it doesn't show in the process list
        id=$(awk -F' *= *' '$1 == "aws_access_key_id" { print $2 }' ${credentials})
        secret=$(awk -F' *= *' '$1 == "aws_secret_access_key" { print $2 }' ${credentials})
        status=$(printf 'user = "%s:%s"\n' "$id" "$secret" | curl --config - \
          --silent --show-error --max-time 30 --retry 3 \
          --aws-sigv4 "aws:amz:auto:s3" \
          --output "$RUNTIME_DIRECTORY/wanted" --write-out '%{http_code}' \
          "https://${cache.endpoint}/${cache.bucket}/deploy/${host}")
        if [ "$status" = 404 ]; then
          echo "CI has published no system for ${host} yet"
          exit 0
        fi
        if [ "$status" != 200 ]; then
          echo "could not read deploy/${host} from the cache: HTTP $status"
          exit 1
        fi

        wanted=$(head -n 1 "$RUNTIME_DIRECTORY/wanted")
        if ! printf '%s\n' "$wanted" | grep -Eqx '/nix/store/[a-z0-9]{32}-nixos-system-${host}-[A-Za-z0-9._+-]+'; then
          echo "deploy/${host} doesn't name a system of this host; ignoring it"
          exit 1
        fi

        running=$(readlink -f /run/current-system)
        if [ "$wanted" = "$running" ]; then
          exit 0
        fi

        echo "updating from $running to $wanted"
        nix-store --realise "$wanted" > /dev/null
        nix-env --profile /nix/var/nix/profiles/system --set "$wanted"
        exec "$wanted/bin/switch-to-configuration" switch
      '';
    };

    systemd.timers.self-deploy = {
      description = "Look regularly for a new system published by CI";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = "2min";
      };
    };
  };
}
