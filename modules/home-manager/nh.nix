{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.nh;
in
{
  options.custom.nh = {
    enable = lib.mkEnableOption "nh, the Nix CLI helper (switch with diffs, search, clean)";
    flake = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/nixos-configs";
      description = "Default flake for nh os/darwin/home commands";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nh = {
      enable = true;
      inherit (cfg) flake;
    };

    programs.zsh.shellAliases = {
      # Manual cleanup of all profiles (user + system): removes generations
      # older than 7 days but always keeps the newest 3, so a rollback
      # target survives even after weeks without a rebuild. Asks first.
      nix-gc = "nh clean all --keep 3 --keep-since 7d --optimise --ask";
    };
  };
}
