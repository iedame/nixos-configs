{ ... }:
{
  # SSH server, reachable only over Tailscale (modules/nixos/ssh-server.nix)
  custom.ssh-server.enable = true;

  # 1Password SSH key (SHA256:u9tymbo3…), the same one that signs commits
  users.users.haoji.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98"
  ];
}
