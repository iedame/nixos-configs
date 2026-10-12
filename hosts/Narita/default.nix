{ ... }:

{
  # Everything about the machine itself is in modules/nixos/oracle-micro.nix
  networking.hostName = "Narita"; # Must match nixosConfigurations.Narita in flake.nix

  # Tailscale exit node: other devices on the tailnet can route their
  # internet traffic through this server. Needs packet forwarding, which
  # "server" turns on; the flag makes Tailscale offer the node (it still
  # has to be allowed once in the admin console).
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # Uptime monitoring. It listens on this machine only and is published
  # on the tailnet as a Tailscale Service, with its own name and HTTPS
  # certificate: https://kuma-narita.<tailnet>.ts.net
  # (modules/nixos/tailscale-services.nix). Nikko runs one too, and each
  # watches the other.
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
    };
  };
  custom.tailscale-services."kuma-narita".target = "http://127.0.0.1:3001";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
