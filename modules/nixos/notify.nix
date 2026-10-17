{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.notify;
  host = config.networking.hostName;

  notify = pkgs.writeShellApplication {
    name = "notify";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: notify <message>" >&2
        exit 2
      fi
      # TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
      # shellcheck source=/dev/null
      . ${lib.escapeShellArg cfg.environmentFile}
      # Sent as plain text: no parse mode, so nothing in the message needs
      # escaping. The token is passed on standard input, to keep it out of
      # the process list.
      printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$TELEGRAM_BOT_TOKEN" |
        curl --config - --fail --silent --show-error --max-time 20 --retry 3 \
          --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
          --data-urlencode "text=${host}: $*" > /dev/null
    '';
  };
in
{
  # A `notify <message>` command that sends a Telegram message, prefixed
  # with the host's name, through the same bot Uptime Kuma alerts with. For
  # things worth knowing that aren't failures (a planned reboot, say);
  # failures are already reported by the heartbeat (heartbeat.nix).
  #
  # The bot's token and the chat's ID are an agenix secret, readable by
  # root only, so the command is for system services (or `sudo notify`).
  # A message that can't be sent makes the command fail; callers for
  # which the message is a courtesy should carry on regardless.
  options.custom.notify = {
    enable = lib.mkEnableOption "the `notify` command, which sends a Telegram message";
    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "File setting TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = notify;
      description = "The `notify` command, for other modules to call.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ notify ];
  };
}
