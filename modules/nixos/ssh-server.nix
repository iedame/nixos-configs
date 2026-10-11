{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.ssh-server;
in
{
  options.custom.ssh-server = {
    enable = lib.mkEnableOption "an SSH server reachable only over Tailscale, with key authentication";
  };

  # Port 22 is opened on tailscale0, not on the LAN or internet. Also
  # generates the ed25519 host key that agenix decrypts with. Authorised
  # keys are set per host (users.users.<name>.openssh.authorizedKeys.keys).
  config = lib.mkIf cfg.enable {
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
  };
}
