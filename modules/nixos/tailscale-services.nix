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

  config.systemd.services = lib.mapAttrs' (
    name: service:
    let
      serve = "tailscale serve --service=svc:${name} --https=${toString service.port} ${lib.escapeShellArg service.target}";
    in
    lib.nameValuePair "tailscale-service-${name}" {
      description = "Publish ${name} as a Tailscale Service";
      wantedBy = [ "multi-user.target" ];
      wants = [ "tailscaled.service" ];
      after = [ "tailscaled.service" ];
      path = [ config.services.tailscale.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # tailscaled may not be ready to take it right after boot
        Restart = "on-failure";
        RestartSec = "30s";
      };
      # Tailscale remembers the setting, so this is normally a no-op; if
      # the port is taken by an older, different setting, start over
      script = ''
        ${serve} || {
          tailscale serve clear svc:${name}
          ${serve}
        }
      '';
    }
  ) cfg;
}
