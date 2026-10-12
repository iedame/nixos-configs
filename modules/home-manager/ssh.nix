{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.ssh;
  inventory = import ../../lib/hosts.nix;

  # 1Password's SSH agent socket (Settings > Developer > Use the SSH agent)
  onePasswordAgent =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
    else
      "~/.1password/agent.sock";

  # The hosts' own keys, under both the address and the name they can be
  # reached by, so ssh knows them without asking and refuses a host that
  # presents a different key
  knownHosts = pkgs.writeText "known-hosts" (
    lib.concatStrings (
      lib.mapAttrsToList (name: host: ''
        ${host.address},${lib.toLower name} ${host.hostKey}
      '') inventory.hosts
    )
  );
in
{
  options.custom.ssh = {
    enable = lib.mkEnableOption "SSH client configuration (1Password agent, host aliases)";
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      # Write only what's below, not home-manager's legacy defaults
      enableDefaultConfig = false;
      # `ssh aurora`, `ssh narita`, ...: one alias per host in lib/hosts.nix
      settings =
        lib.mapAttrs' (
          name: host:
          lib.nameValuePair (lib.toLower name) {
            HostName = host.address;
            User = inventory.admin.user;
          }
        ) inventory.hosts
        // {
          "*" = {
            # Keys live in 1Password; the agent offers them and asks to approve
            IdentityAgent = onePasswordAgent;
            # The usual file for everything else, plus the pinned keys of
            # the hosts in lib/hosts.nix
            UserKnownHostsFile = "~/.ssh/known_hosts ${knownHosts}";
          };
        };
    };
  };
}
