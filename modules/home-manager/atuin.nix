{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.atuin;
  # The server's address names the tailnet, so it isn't in this repository:
  # each machine keeps it in this file (README.md, "Atuin" in
  # hosts/Ginza/README.md)
  addressFile = "${config.xdg.configHome}/atuin/sync-address";
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
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        search_mode = "fuzzy";
        style = "compact";
        # Ctrl-R starts with every machine's history; Ctrl-R again cycles
        # to this host, this session and this directory
        filter_mode = "global";
        enter_accept = false;
      };
    };

    # fzf (custom.shell-tools) also binds Ctrl-R; Atuin's search replaces
    # it there, while fzf keeps Ctrl-T and Alt-C
    programs.fzf.historyWidget.command = "";

    # The server's address, as ATUIN_SYNC_ADDRESS. Atuin's config file
    # overrides its environment, so sync_address must not be in the file
    # (settings above). Without the address file it goes nowhere, instead
    # of to Atuin's public server, the built-in default.
    programs.zsh.initContent = ''
      if [ -r ${addressFile} ]; then
        export ATUIN_SYNC_ADDRESS="$(< ${addressFile})"
      else
        export ATUIN_SYNC_ADDRESS=https://atuin.invalid
      fi
    '';
  };
}
