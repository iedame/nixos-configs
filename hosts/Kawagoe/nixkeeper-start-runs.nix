{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.nixkeeper-start-runs;
in
{
  # Starts nixkeeper's runs on time through GitHub's API (GitHub's own
  # schedule skips runs when busy). Narita normally does this
  # (hosts/Narita/nixkeeper-start-runs.nix); this is the stand-in for when
  # that server is down: set enable = true in default.nix and rebuild.
  # Running both at once is harmless, a run started twice finds nothing new.
  #
  # Token: Keychain item "nixkeeper-start-runs".
  options.custom.nixkeeper-start-runs.enable = lib.mkEnableOption "starting nixkeeper's runs from this Mac, hourly";

  config = lib.mkIf cfg.enable {
    launchd.user.agents.nixkeeper-start-runs.serviceConfig = {
      ProgramArguments = [
        (lib.getExe inputs.nixkeeper.packages.${pkgs.stdenv.hostPlatform.system}.start-runs)
      ];
      StartCalendarInterval = [ { Minute = 15; } ]; # hourly, at :15
      StandardOutPath = "/Users/haoji/Library/Logs/nixkeeper-start-runs.log";
      StandardErrorPath = "/Users/haoji/Library/Logs/nixkeeper-start-runs.log";
    };

    # Reported as unhealthy when it last ended in an error
    custom.heartbeat.agents = [ "org.nixos.nixkeeper-start-runs" ];
  };
}
