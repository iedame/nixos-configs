{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.atuin;
  # The server's address names the tailnet, so it isn't in this repository:
  # each machine keeps it in this file (README.md, "Atuin" in
  # hosts/Ginza/README.md)
  addressFile = "${config.xdg.configHome}/atuin/sync-address";
  configFile = "${config.xdg.configHome}/atuin/config.toml";

  settings = (pkgs.formats.toml { }).generate "atuin-config" {
    auto_sync = true;
    sync_frequency = "5m";
    search_mode = "fuzzy";
    style = "compact";
    # Ctrl-R starts with every machine's history; Ctrl-R again cycles to
    # this host, this session and this directory
    filter_mode = "global";
    enter_accept = false;
    # Inside a git repository, Ctrl-R also cycles to that repository's
    # commands, wherever in it they were run
    workspaces = true;
    # Never recorded, so an old one can't be picked from the search and run
    # again in the wrong place (regular expressions over the whole command)
    history_filter = [
      "^rm "
      "^shred "
      "^dd "
    ];
  };
in
{
  options.custom.atuin = {
    enable = lib.mkEnableOption "Atuin shell history, synced through the server on Ginza";
  };

  config = lib.mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      # Ctrl-R opens Atuin's search; the up arrow keeps stepping through
      # this shell's own history as before
      flags = [ "--disable-up-arrow" ];
      # Written below instead, with the server's address in it
      settings = { };
    };

    # fzf (custom.shell-tools) also binds Ctrl-R; Atuin's search replaces
    # it there, while fzf keeps Ctrl-T and Alt-C
    programs.fzf.historyWidget.command = "";

    # The config file, written at every switch: the settings above plus
    # sync_address from the address file. Every atuin command reads it,
    # whatever shell or environment it runs in. Without the address file
    # the address goes nowhere, instead of to Atuin's public server, the
    # built-in default. After creating or changing that file, switch again.
    home.activation.atuinConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      address=https://atuin.invalid
      if [ -r ${lib.escapeShellArg addressFile} ]; then
        address=$(head -n 1 ${lib.escapeShellArg addressFile})
      fi
      run mkdir -p ${lib.escapeShellArg (builtins.dirOf configFile)}
      # Earlier generations linked it into the Nix store
      run rm -f ${lib.escapeShellArg configFile}
      run install -m 644 ${settings} ${lib.escapeShellArg configFile}
      if [ -z "''${DRY_RUN:-}" ]; then
        printf 'sync_address = "%s"\n' "$address" >> ${lib.escapeShellArg configFile}
      fi
    '';
  };
}
