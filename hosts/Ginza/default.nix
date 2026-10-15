{ config, ... }:

{
  imports = [ ./secrets.nix ];

  # Everything about the machine itself is in modules/nixos/oracle-a1.nix
  # and oracle.nix; this file has the name and what this host runs.
  networking.hostName = "Ginza"; # Must match nixosConfigurations.Ginza in flake.nix

  # For the conversion from Ubuntu only (hosts/Ginza/README.md), removed
  # once it is done. NixOS moves the old system aside on first boot
  # (/etc/NIXOS_LUSTRATE), which only the scripted initrd does; and SSH
  # stays reachable on the public address in case Tailscale doesn't come
  # back.
  boot.initrd.systemd.enable = false;
  custom.ssh-server.openToInternet = true;

  # This host is the tailnet's DNS server (below), so it doesn't take its
  # own DNS settings from Tailscale: it keeps resolving through Oracle's
  # resolver, and so keeps updating itself even when Blocky is down.
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

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

  # DNS for the tailnet, with ads and trackers blocked. Tailscale's admin
  # console points the tailnet's devices here (DNS, global nameserver: this
  # host's Tailscale address); names on the tailnet itself (MagicDNS) are
  # still answered by Tailscale on each device. Blocky answers on port 53,
  # which the firewall opens on the Tailscale interface only, and asks
  # Quad9 and Cloudflare over HTTPS.
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      upstreams.groups.default = [
        "https://dns.quad9.net/dns-query"
        "https://cloudflare-dns.com/dns-query"
      ];
      # How Blocky finds the two resolvers above before it can resolve
      # anything
      bootstrapDns = [
        {
          upstream = "https://dns.quad9.net/dns-query";
          ips = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        }
        {
          upstream = "https://cloudflare-dns.com/dns-query";
          ips = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        }
      ];
      blocking = {
        denylists.ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
        clientGroupsBlock.default = [ "ads" ];
        # Answer straight away at start-up, and block once the list is in
        loading.strategy = "fast";
      };
      caching.prefetching = true;
    };
  };
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  # Reports this host's health to Narita's Uptime Kuma, which alerts if a
  # unit fails here or the reports stop (modules/nixos/heartbeat.nix). The
  # monitor's push URL is an agenix secret (secrets.nix).
  custom.heartbeat = {
    enable = true;
    urlFile = config.age.secrets."heartbeat-url".path;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
