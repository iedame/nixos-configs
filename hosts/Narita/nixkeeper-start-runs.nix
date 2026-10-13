{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Starts nixkeeper's runs on time through GitHub's API (GitHub's own
  # schedule skips runs when busy), hourly at :15. It needs a machine that
  # is always on, which is why it lives here.
  #
  # The token is a fine-grained GitHub one for the nixkeeper repositories
  # with only "Actions: read and write", kept as an agenix secret
  # (secrets.nix). systemd hands it to the service as a credential, so the
  # service runs as a throwaway user that can read nothing else.
  #
  # A start GitHub keeps refusing makes the run fail, which the heartbeat
  # reports (default.nix).
  systemd.services.nixkeeper-start-runs = {
    description = "Start nixkeeper's runs through GitHub's API";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      LoadCredential = "token:${config.age.secrets."nixkeeper-start-runs-token".path}";
      ExecStart = lib.getExe inputs.nixkeeper.packages.${pkgs.stdenv.hostPlatform.system}.start-runs;
    };
  };

  systemd.timers.nixkeeper-start-runs = {
    description = "Start nixkeeper's runs hourly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # The minute is the same in UTC, which is what the script goes by:
      # this host's time zone is a whole number of hours away from it
      OnCalendar = "*:15";
      AccuracySec = "10s";
      # A start missed while the server was off runs at boot
      Persistent = true;
    };
  };
}
