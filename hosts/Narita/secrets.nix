{ inputs, ... }:
{
  # The encrypted files live in the private `secrets` flake input (see
  # flake.nix). agenix decrypts them at activation with the SSH host key
  # (modules/nixos/oracle-micro.nix) into /run/agenix/<name>, readable by
  # root only, which is what the services reading them run as.
  age.secrets = {
    # Push URL of this host's monitor on Nikko's Uptime Kuma
    "heartbeat-url".file = "${inputs.secrets}/narita/heartbeat-url.age";
  };
}
