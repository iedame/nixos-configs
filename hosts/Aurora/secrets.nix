{
  inputs,
  pkgs,
  ...
}:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (ssh.nix) into /run/agenix/<name>. All three are read by systemd as root
  # (EnvironmentFile), so agenix's default root-only 0400 permissions work.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    # Cloudflare API token for the ACME DNS challenge
    "cloudflare-dns.env".file = "${inputs.secrets}/aurora/cloudflare-dns.env.age";
    "vaultwarden.env".file = "${inputs.secrets}/aurora/vaultwarden.env.age";
    "linkding.env".file = "${inputs.secrets}/aurora/linkding.env.age";
  };

  # agenix CLI, for editing the secrets (in a clone of the private repo)
  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Lets age encrypt to (and decrypt with) the YubiKey recovery
    # recipients in the secrets repo's agenix-rules.nix
    pkgs.age-plugin-yubikey
  ];
}
