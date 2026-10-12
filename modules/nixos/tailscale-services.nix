{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.tailscale-services;
in
{
  # A Tailscale Service gives something running on this host its own name
  # and HTTPS certificate on the tailnet (https://<name>.<tailnet>.ts.net),
  # independent of the host's name. Besides this, the service has to be
  # defined in the admin console, this host approved for it, and access to
  # svc:<name> granted in the access rules.
  #
  # A device only sees a service (its name doesn't even resolve) if a rule
  # lets that device's tag reach it. That includes the host itself: for a
  # host to open its own service address, its tag needs such a rule too.
  #
  # nixpkgs has services.tailscale.serve for this, but its configuration
  # file can't express "HTTPS on the tailnet, plain HTTP locally" (as of
  # Tailscale 1.102 the local scheme decides both sides), so this runs the
  # `tailscale serve` command instead.
  options.custom.tailscale-services = lib.mkOption {
    default = { };
    example = {
      kuma.target = "http://127.0.0.1:3001";
    };
    description = "Local web services to publish as Tailscale Services, by service name.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 443;
            description = "Port the service answers on, with HTTPS.";
          };
          target = lib.mkOption {
            type = lib.types.str;
            example = "http://127.0.0.1:3001";
            description = "Where requests are sent on this host.";
          };
        };
      }
    );
  };

  # One unit applies the whole set: it publishes every service declared
  # above and withdraws the ones that were declared before and no longer
  # are. Tailscale keeps serve settings in its own state, so without that
  # second part a service removed from the configuration would stay
  # published. The unit remembers what it published in its state directory
  # and only ever withdraws those, never a service set up by hand.
  config.systemd.services.tailscale-services = lib.mkIf config.services.tailscale.enable {
    description = "Publish the declared Tailscale Services";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    path = [ config.services.tailscale.package ];
    # With nothing declared there is only work to do if something was
    # published earlier
    unitConfig.ConditionPathExists = lib.mkIf (cfg == { }) "/var/lib/tailscale-services/managed";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "tailscale-services";
      # tailscaled may not be ready to take it right after boot
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      managed="$STATE_DIRECTORY/managed"
      wanted=${lib.escapeShellArg (lib.concatStringsSep " " (lib.attrNames cfg))}

      if [ -f "$managed" ]; then
        while read -r name; do
          case " $wanted " in
            *" $name "*) ;;
            *)
              echo "withdrawing svc:$name"
              tailscale serve clear "svc:$name" || echo "svc:$name was already gone"
              ;;
          esac
        done < "$managed"
      fi

      ${lib.concatStrings (
        lib.mapAttrsToList (
          name: service:
          let
            serve = "tailscale serve --service=svc:${name} --https=${toString service.port} ${lib.escapeShellArg service.target}";
          in
          ''
            # Normally a no-op, since Tailscale remembers the setting; if the
            # port is taken by an older, different one, start over
            ${serve} || {
              tailscale serve clear svc:${name}
              ${serve}
            }
          ''
        ) cfg
      )}
      if [ -n "$wanted" ]; then
        printf '%s\n' $wanted > "$managed"
      else
        rm -f "$managed"
      fi
    '';
  };
}
