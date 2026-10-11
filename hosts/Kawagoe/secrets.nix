{ inputs, pkgs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the macOS SSH host
  # key (present even with Remote Login off).
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Decrypted at activation to /run/agenix/test (root:wheel 0400)
  age.secrets.test.file = "${inputs.secrets}/kawagoe/test.age";

  # linkding runs as a user agent (users/haoji), so its environment file has
  # to be readable by that user rather than by root
  age.secrets."linkding.env" = {
    file = "${inputs.secrets}/kawagoe/linkding.env.age";
    owner = "haoji";
  };

  # agenix CLI for editing the secrets in ~/.config/nixos-secrets (identity:
  # ~/.ssh/agenix)
  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Lets age encrypt to (and decrypt with) the YubiKey recovery
    # recipients in the secrets repo's agenix-rules.nix
    pkgs.age-plugin-yubikey
  ];
}
