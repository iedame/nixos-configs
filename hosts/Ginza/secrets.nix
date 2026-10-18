{ inputs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (modules/nixos/oracle.nix) into /run/agenix/<name>, readable by root
  # only, which is what the services reading them run as.
  age.secrets = {
    # Push URL of this host's monitor on Narita's Uptime Kuma
    "heartbeat-url".file = "${inputs.secrets}/ginza/heartbeat-url.age";
    # linkding's environment: the settings that name the tailnet
    "linkding.env".file = "${inputs.secrets}/ginza/linkding.env.age";
    # R2 token and encryption password for the backup of linkding; the same
    # file as Narita's and Nikko's backups of Uptime Kuma
    "backup.env".file = "${inputs.secrets}/shared/backup.env.age";
    # Read-only R2 token for the binary cache, linked to where Nix looks
    # for it. A newly installed host needs the file placed by hand once, to
    # download its first system (see "Binary cache" in the top-level
    # README); from then on this replaces it.
    "cache-credentials" = {
      file = "${inputs.secrets}/shared/cache-credentials.age";
      path = "/root/.aws/credentials";
    };
    # Telegram bot token and chat ID for `notify` (custom.notify); the same
    # file on all three servers
    "telegram.env".file = "${inputs.secrets}/shared/telegram.env.age";
    # Beszel agent settings: the hub's address, a universal token and the
    # hub's public key (custom.beszel-agent); the same file on every host
    "beszel-agent.env".file = "${inputs.secrets}/shared/beszel-agent.env.age";
    # Vaultwarden's settings that stay out of the repository: DOMAIN (its
    # Tailscale Service address, which names the tailnet) and ADMIN_TOKEN;
    # the same as Aurora's otherwise
    "vaultwarden.env".file = "${inputs.secrets}/ginza/vaultwarden.env.age";
  };
}
