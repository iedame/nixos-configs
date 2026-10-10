{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.nix-index;
in
{
  options.custom.nix-index = {
    enable = lib.mkEnableOption "nix-index with the prebuilt nix-index-database (command-not-found, comma, nix-locate)";
  };

  # The database comes from the nix-index-database flake input, refreshed by
  # the weekly flake update instead of being built locally.
  config = lib.mkIf cfg.enable {
    programs.nix-index = {
      enable = true;
      # "command not found" handler that suggests the providing package
      enableZshIntegration = true;
    };
    # `, <cmd>` runs a program from nixpkgs without installing it
    programs.nix-index-database.comma.enable = true;
  };
}
