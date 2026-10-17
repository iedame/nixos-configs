{ inputs, pkgs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the macOS SSH host
  # key (present even with Remote Login off).
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Decrypted at activation to /run/agenix/test (root:wheel 0400)
  age.secrets.test.file = "${inputs.secrets}/kawagoe/test.age";

  # Push URL of this Mac's monitor in Uptime Kuma (custom.heartbeat,
  # default.nix); read by a root launchd job
  age.secrets."heartbeat-url".file = "${inputs.secrets}/kawagoe/heartbeat-url.age";

  # Beszel agent settings: the hub's address, a universal token and the
  # hub's public key (custom.beszel-agent, default.nix); the file the Linux
  # hosts use
  age.secrets."beszel-agent.env".file = "${inputs.secrets}/shared/beszel-agent.env.age";

  # agenix CLI for editing the secrets in ~/.config/nixos-secrets (identity:
  # ~/.ssh/agenix)
  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Lets age encrypt to (and decrypt with) the YubiKey recovery
    # recipients in the secrets repo's agenix-rules.nix
    pkgs.age-plugin-yubikey
  ];
}
