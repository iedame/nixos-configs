{
  config,
  pkgs,
  ...
}:
let
  nara = (import ../../lib/hosts.nix).hosts.Nara;
  dataset = "external-pool/immich";
  dest = "/${dataset}";
  knownHosts = pkgs.writeText "nara-known-hosts" "${nara.address} ${nara.hostKey}\n";
  # Nara's immich-mirror account (hosts/Nara/immich.nix) runs rrsync for
  # this key, read-only and limited to Immich's library, so remote paths
  # are relative to the library
  source = "immich-mirror@${nara.address}:";
  # How many snapshots to keep: one per day with a pull, so about a month
  # of days on which Aurora was on
  keep = 30;
in
{
  # A copy of Immich's library, which lives on Nara (on its storage box
  # share), on this machine's external pool: the photos' backup now that
  # Immich has moved. Pulled whenever this machine is on, as it is often
  # off, with a ZFS snapshot after each run, so a photo deleted or damaged
  # on Nara can still be found here for a while. Immich's own nightly
  # database dumps are in the library (backups/), so they come along.
  #
  # The dataset is made once by hand (README.md, "Immich's mirror"); the
  # job fails, and the heartbeat reports it, while it isn't mounted.
  systemd.services.immich-mirror = {
    description = "Pull a mirror of Immich's library from Nara";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [
      config.boot.zfs.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.openssh
      pkgs.rsync
      pkgs.util-linux
    ];
    environment.RSYNC_RSH = "ssh -i ${
      config.age.secrets."immich-mirror-ssh-key".path
    } -o IdentitiesOnly=yes -o BatchMode=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes";
    # The run that catches up at boot can start before Nara is reachable
    # over Tailscale (on 2026-10-23 its connection timed out two minutes
    # after boot): a failed run is tried again 5 minutes later, three times
    # in all, before it counts as failed, which the heartbeat reports. The
    # limit covers 30 minutes, so the hourly check below can start it again
    # the next hour.
    startLimitBurst = 3;
    startLimitIntervalSec = 30 * 60;
    # A switch leaves a run alone (as nixpkgs does for nix-gc): one waiting
    # between those tries would otherwise be started again at once, while
    # the switch is restarting Tailscale, fail, and fail the switch with it
    # (2026-10-27). The timer starts the next run with the new unit.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "5min";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -o pipefail
      # The external pool is a USB disk: never fill the empty folder below
      # a missing dataset
      mountpoint --quiet ${dest}

      # Nor mirror an empty folder below a missing share on Nara as
      # "everything was deleted": Immich keeps a marker file in each of its
      # folders
      rsync --list-only ${source}library/.immich > /dev/null

      # --max-delete: a run that would delete more than this stops (and
      # fails) instead; the snapshots still hold everything
      rsync --archive --hard-links --delete --max-delete=2000 \
        --info=stats1 ${source} ${dest}/

      zfs snapshot ${dataset}@mirror-$(date +%Y-%m-%d-%H%M)
      zfs list -H -t snapshot -o name -s creation -d 1 ${dataset} \
        | grep '@mirror-' | head -n -${toString keep} \
        | while read -r snapshot; do zfs destroy "$snapshot"; done
    '';
  };

  # Every hour, start a pull unless today's has already succeeded (it made
  # today's snapshot). So a day's pull happens at the first hour the
  # machine is on and Nara is reachable: a failed one is tried again the
  # next hour, not the next day (on 2026-10-29 the boot's tries ran out
  # in 15 minutes without a network). A pull started by hand always runs.
  systemd.services.immich-mirror-daily = {
    description = "Start today's Immich mirror pull, unless it is done";
    startAt = "hourly";
    path = [
      config.boot.zfs.package
      config.systemd.package
      pkgs.coreutils
      pkgs.gnugrep
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      if zfs list -H -t snapshot -o name -d 1 ${dataset} \
        | grep --quiet "@mirror-$(date +%Y-%m-%d)-"; then
        echo "Today's pull is done"
      else
        systemctl start --no-block immich-mirror.service
      fi
    '';
  };
  # This machine is often off: check when it is next on instead
  systemd.timers.immich-mirror-daily.timerConfig.Persistent = true;
}
