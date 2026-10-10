{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Starts nixkeeper's runs on time through GitHub's API (GitHub's own
  # schedule skips runs when busy). Token: Keychain item "nixkeeper-start-runs".
  launchd.user.agents.nixkeeper-start-runs.serviceConfig = {
    ProgramArguments = [
      (lib.getExe inputs.nixkeeper.packages.${pkgs.stdenv.hostPlatform.system}.start-runs)
    ];
    StartCalendarInterval = [ { Minute = 15; } ]; # hourly, at :15
    StandardOutPath = "/Users/haoji/Library/Logs/nixkeeper-start-runs.log";
    StandardErrorPath = "/Users/haoji/Library/Logs/nixkeeper-start-runs.log";
  };
}
