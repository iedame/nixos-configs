{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.ssh;

  # 1Password's SSH agent socket (Settings > Developer > Use the SSH agent)
  onePasswordAgent =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
    else
      "~/.1password/agent.sock";
in
{
  options.custom.ssh = {
    enable = lib.mkEnableOption "SSH client configuration (1Password agent, host aliases)";
    auroraAddress = lib.mkOption {
      type = lib.types.str;
      # Aurora's Tailscale IP: stable even if its Tailscale name changes
      default = "100.110.116.3";
      description = "Address for the `aurora` host alias";
    };
    tsukubaAddress = lib.mkOption {
      type = lib.types.str;
      # Tsukuba's Tailscale IP; its SSH server listens on Tailscale only
      default = "100.115.41.1";
      description = "Address for the `tsukuba` host alias";
    };
    naritaAddress = lib.mkOption {
      type = lib.types.str;
      # Narita's Tailscale IP, kept across its conversion from Ubuntu
      default = "100.111.191.17";
      description = "Address for the `narita` host alias";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      # Write only what's below, not home-manager's legacy defaults
      enableDefaultConfig = false;
      settings = {
        aurora = {
          HostName = cfg.auroraAddress;
          User = "haoji";
        };
        tsukuba = {
          HostName = cfg.tsukubaAddress;
          User = "haoji";
        };
        narita = {
          HostName = cfg.naritaAddress;
          User = "haoji";
        };
        "*" = {
          # Keys live in 1Password; the agent offers them and asks to approve
          IdentityAgent = onePasswordAgent;
        };
      };
    };
  };
}
