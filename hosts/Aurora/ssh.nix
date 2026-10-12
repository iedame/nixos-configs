{ ... }:
{
  # SSH server, reachable only over Tailscale, with my key authorised
  # (modules/nixos/ssh-server.nix, lib/hosts.nix)
  custom.ssh-server.enable = true;
}
