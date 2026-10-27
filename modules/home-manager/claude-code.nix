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
        # TEMPORARY: nixpkgs moved python3Packages.mcp to 2.x, which
        # fastmcp (through fastmcp-slim, now marked broken) doesn't support
        # yet. Build mcp-nixos against mcp 1.x, as nixpkgs did for ha-mcp
        # (NixOS/nixpkgs#578535). Drop this once mcp-nixos evaluates again.
        command = lib.getExe (
          pkgs.mcp-nixos.override {
            python3Packages = pkgs.python3Packages.overrideScope (final: prev: { mcp = final.mcp_1; });
          }
        );
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
