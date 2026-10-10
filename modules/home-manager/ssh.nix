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
        "*" = {
          # Keys live in 1Password; the agent offers them and asks to approve
          IdentityAgent = onePasswordAgent;
        };
      };
    };
  };
}
