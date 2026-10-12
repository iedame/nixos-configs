{
  inputs,
  pkgs,
  ...
}:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (ssh.nix) into /run/agenix/<name>. All are read as root (systemd's
  # EnvironmentFile, the heartbeat, Nix), so agenix's default root-only 0400
  # permissions work.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    # Cloudflare API token for the ACME DNS challenge
    "cloudflare-dns.env".file = "${inputs.secrets}/aurora/cloudflare-dns.env.age";
    "vaultwarden.env".file = "${inputs.secrets}/aurora/vaultwarden.env.age";
    "linkding.env".file = "${inputs.secrets}/aurora/linkding.env.age";
    # Push URL of this host's monitor in Uptime Kuma (custom.heartbeat)
    "heartbeat-url".file = "${inputs.secrets}/aurora/heartbeat-url.age";
    # Read-only R2 token for the binary cache, linked to where Nix looks
    # for it (see "Binary cache" in the top-level README)
    "cache-credentials" = {
      file = "${inputs.secrets}/aurora/cache-credentials.age";
      path = "/root/.aws/credentials";
    };
    # Off-site backups (backup.nix): how to reach the storage box (an SSH
    # configuration naming its accounts), the key it accepts, and each
    # repository's passphrase
    "borg-ssh-config".file = "${inputs.secrets}/aurora/borg-ssh-config.age";
    "borg-ssh-key".file = "${inputs.secrets}/aurora/borg-ssh-key.age";
    "borg-immich-passphrase".file = "${inputs.secrets}/aurora/borg-immich-passphrase.age";
    "borg-home-passphrase".file = "${inputs.secrets}/aurora/borg-home-passphrase.age";
  };

  # agenix CLI, for editing the secrets (in a clone of the private repo)
  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Lets age encrypt to (and decrypt with) the YubiKey recovery
    # recipients in the secrets repo's agenix-rules.nix
    pkgs.age-plugin-yubikey
  ];
}
