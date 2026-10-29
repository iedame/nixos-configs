{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.claude-code;
in
{
  options.custom.claude-code = {
    enable = lib.mkEnableOption "Claude Code CLI with the nixos MCP server";
  };

  config = lib.mkIf cfg.enable {
    # The `claude` CLI. settings.json is deliberately not managed here, so
    # Claude (CLI and desktop app) can keep writing its own settings.
    programs.claude-code = {
      enable = true;

      # Package/option lookups for nixpkgs, NixOS, home-manager and
      # nix-darwin. Home-manager ships this as a generated plugin in
      # ~/.claude, so the tools are named mcp__plugin_hm_nixos__*.
      mcpServers.nixos = {
        type = "stdio";
        command = lib.getExe pkgs.mcp-nixos;
      };
    };

    # Claude shells out to these for clipboard access on Linux (image paste
    # doesn't work without them); the nixpkgs wrapper doesn't include them
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.wl-clipboard
      pkgs.xclip
    ];
  };
}
