# The machines of this repository that accept SSH, and who may log in to
# them. Plain data, read with `import` by:
#
#   modules/home-manager/ssh.nix   an `ssh <name>` alias for every host
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
  # Tailscale only.
  hosts = {
    Aurora.address = "100.110.116.3";
    Narita.address = "100.111.191.17";
    Nikko.address = "100.78.232.17";
    Tsukuba.address = "100.115.41.1";
  };
}
