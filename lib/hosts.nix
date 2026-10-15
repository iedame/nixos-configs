# The machines of this repository that accept SSH, and who may log in to
# them. Plain data, read with `import` by:
#
#   modules/home-manager/ssh.nix   an `ssh <name>` alias for every host, and
#                                  its pinned host key
#   modules/nixos/ssh-server.nix   the key authorised on every host
#   modules/home-manager/git.nix   the same key signs commits
#   hosts/Aurora/services.nix      the address Aurora's services bind to
#
# A new host that should be reachable over SSH gets an entry here.
{
  # The one administrator. The key lives in 1Password
  # (SHA256:u9tymbo3MxmadJAyyJvRq4C+qerPciuRvMU9CMk1GTY); it is also a
  # GitHub login key.
  admin = {
    user = "haoji";
    key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98";
  };

  # By flake host name. `address` is the Tailscale IP, which stays the same
  # if the machine is renamed on the tailnet; the SSH servers listen on
  # Tailscale only. `hostKey` is the machine's own SSH key, the contents of
  # its /etc/ssh/ssh_host_ed25519_key.pub: clients are told to expect
  # exactly this key, so it has to be updated here if a machine is
  # reinstalled (the Oracle hosts kept theirs across the conversion).
  hosts = {
    Aurora = {
      address = "100.110.116.3";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICsrX+QjUTslwb3hJQxDMgFElXbUt1qv+jGsDCwnFhlL";
    };
    Kawaguchiko = {
      address = "100.118.90.64";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINozjjMQunxp6OHJBBVFtS6IkHiZSd/WeHzke+dF9ims";
    };
    Ginza = {
      address = "100.114.25.47";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINY3du1Y4H5un/N5Dg3lfykUVdoCtI7dkBZXWrFPFusF";
    };
    Narita = {
      address = "100.111.191.17";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPep0HwSN8SjvyY5MVuHh3rLOzFbYE9l2goJjmPJmeFo";
    };
    Nikko = {
      address = "100.78.232.17";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKeHiyIyphuQ1hlQ7sy+ncRlK9ITk6nKGqo08u51BCWP";
    };
    Tsukuba = {
      address = "100.115.41.1";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyxAE1e6jKPWUGoXr26i96bpKzXtpHtc+wUTtkWVhRV";
    };
  };
}
