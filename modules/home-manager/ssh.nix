{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.custom.ssh;
  inventory = import ../../lib/hosts.nix;

  # 1Password's SSH agent socket (Settings > Developer > Use the SSH agent).
  # Under WSL, 1Password runs on Windows, and NixOS-WSL's bridge to it
  # (wsl.ssh-agent) is announced in SSH_AUTH_SOCK, which this value makes
  # ssh read.
  onePasswordAgent =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
    else if osConfig.wsl.ssh-agent.enable or false then
      "SSH_AUTH_SOCK"
    else
      "~/.1password/agent.sock";

  # nix-community's builders, for building and reviewing nixpkgs work
  # (docs/community-builders.md in github.com/nix-community/infra, which
  # also publishes their host keys). Only public nixpkgs work goes there,
  # never these hosts' own systems.
  communityBuilders = {
    build-box = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElIQ54qAy7Dh63rBudYKdbzJHrrbrrMXLYl7Pkmk88H";
    aarch64-build-box = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9uyfhyli+BRtk64y+niqtb+sKquRGGZ87f4YRc8EE1";
    darwin-build-box = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMHhlcn7fUpUuiOFeIhDqBzBNFsbNqq+NpzuGX3e6zv";
  };

  # The public half of the key the builders know us by (1Password item
  # "nix-community builders"). Given as the identity, it makes ssh ask the
  # agent for that key only, not every key in 1Password.
  communityBuildersKey = pkgs.writeText "nix-community-builders.pub" ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIquXHtmTC81sELVG6TFhmDJ04Nt5hj1QZcANm46yvv
  '';

  # The hosts' own keys, under both the address and the name they can be
  # reached by, so ssh knows them without asking and refuses a host that
  # presents a different key
  knownHosts = pkgs.writeText "known-hosts" (
    lib.concatStrings (
      lib.mapAttrsToList (name: host: ''
        ${host.address},${lib.toLower name} ${host.hostKey}
      '') inventory.hosts
      ++ lib.mapAttrsToList (name: key: ''
        ${name}.nix-community.org ${key}
      '') communityBuilders
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
        # `ssh build-box`, `ssh aarch64-build-box`, `ssh darwin-build-box`
        // lib.mapAttrs (name: _: {
          HostName = "${name}.nix-community.org";
          User = "iedame";
          IdentityFile = "${communityBuildersKey}";
          IdentitiesOnly = "yes";
        }) communityBuilders
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
