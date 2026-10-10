{ ... }:
{
  # SSH server, reachable only over Tailscale (port 22 is opened on
  # tailscale0 below, not on the LAN or internet). Also generates the
  # ed25519 host key that agenix decrypts with.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

  # 1Password SSH key (SHA256:u9tymbo3…), the same one that signs commits
  users.users.haoji.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98"
  ];
}
