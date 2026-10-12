{ inputs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (modules/nixos/oracle-micro.nix) into /run/agenix/<name>, readable by
  # root only, which is what the services reading them run as.
  age.secrets = {
    # Push URL of this host's monitor on Nikko's Uptime Kuma
    "heartbeat-url".file = "${inputs.secrets}/narita/heartbeat-url.age";
    # R2 token and encryption password for the backup of Uptime Kuma; the
    # same file on both servers
    "backup.env".file = "${inputs.secrets}/shared/backup.env.age";
    # Read-only R2 token for the binary cache, linked to where Nix looks
    # for it. A newly installed host needs the file placed by hand once, to
    # download its first system (see "Binary cache" in the top-level
    # README); from then on this replaces it.
    "cache-credentials" = {
      file = "${inputs.secrets}/shared/cache-credentials.age";
      path = "/root/.aws/credentials";
    };
  };
}
