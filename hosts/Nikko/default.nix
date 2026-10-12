{ ... }:

{
  # Everything about the machine itself is in modules/nixos/oracle-micro.nix
  networking.hostName = "Nikko"; # Must match nixosConfigurations.Nikko in flake.nix

  # Tailscale exit node: other devices on the tailnet can route their
  # internet traffic through this server. Needs packet forwarding, which
  # "server" turns on; the flag makes Tailscale offer the node (it still
  # has to be allowed once in the admin console).
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # Uptime monitoring, reachable over Tailscale only: http://nikko:3001.
  # Narita runs one too, so each can watch the other.
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3001 ];

  # The same Uptime Kuma as a Tailscale Service, with its own name and
  # HTTPS certificate: https://kuma-nikko.<tailnet>.ts.net
  # (modules/nixos/tailscale-services.nix)
  custom.tailscale-services."kuma-nikko".target = "http://127.0.0.1:3001";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
