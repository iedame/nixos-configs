{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.ssh-server;
  inventory = import ../../lib/hosts.nix;
in
{
  options.custom.ssh-server = {
    enable = lib.mkEnableOption "an SSH server reachable only over Tailscale, with key authentication";
    openToInternet = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also accept SSH on every interface, not just Tailscale. For a cloud
        host that hasn't joined the tailnet yet.
      '';
    };
  };

  # Port 22 is opened on tailscale0, not on the LAN or internet. Also
  # generates the ed25519 host key that agenix decrypts with. The one key
  # that may log in, and the account it logs in to, come from lib/hosts.nix.
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

    users.users.${inventory.admin.user}.openssh.authorizedKeys.keys = [ inventory.admin.key ];

    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openToInternet [ 22 ];
  };
}
