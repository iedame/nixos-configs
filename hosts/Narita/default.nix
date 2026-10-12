{ ... }:

{
  # Everything about the machine itself is in modules/nixos/oracle-micro.nix
  networking.hostName = "Narita"; # Must match nixosConfigurations.Narita in flake.nix

  # Kept open (key only) through the conversion from Ubuntu, in case
  # Tailscale doesn't come back up. Set to false once it has.
  custom.ssh-server.openToInternet = true;

  # Uptime monitoring, reachable over Tailscale only: http://narita:3001
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3001 ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
