{ inputs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (modules/nixos/cloud-server.nix) into /run/agenix/<name>, readable by
  # root only, which is what the services reading them run as.
  age.secrets = {
    # Read-only R2 token for the binary cache, linked to where Nix looks
    # for it. The first system needs the file placed by hand (see "Binary
    # cache" in the top-level README); from then on this replaces it.
    "cache-credentials" = {
      file = "${inputs.secrets}/shared/cache-credentials.age";
      path = "/root/.aws/credentials";
    };
    # Beszel agent settings: the hub's address, a universal token and the
    # hub's public key (custom.beszel-agent); the same file on every host
    "beszel-agent.env".file = "${inputs.secrets}/shared/beszel-agent.env.age";
    # Telegram bot token and chat ID for `notify` (custom.notify); the same
    # file on all the servers
    "telegram.env".file = "${inputs.secrets}/shared/telegram.env.age";
    # Uptime Kuma push URL for this host's heartbeat (custom.heartbeat)
    "heartbeat-url".file = "${inputs.secrets}/nara/heartbeat-url.age";
    # The storage box sub-account holding Immich's library, as a CIFS
    # credentials file: username= and password= (storage-box.nix)
    "immich-library-smb".file = "${inputs.secrets}/nara/immich-library-smb.age";
  };
}
