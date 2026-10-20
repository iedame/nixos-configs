{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Machine learning runs on Aurora, which has a GPU and the memory for it
  auroraIp = (import ../../lib/hosts.nix).hosts.Aurora.address;
in
{
  # Immich, moving here from Aurora so photo backups don't depend on the
  # desktop being on. It listens on this machine only and is published as
  # the Tailscale Service svc:immich (https://immich.<tailnet>.ts.net).
  #
  # The whole media folder (originals, thumbnails, transcoded videos and
  # Immich's own database dumps) is the storage box share mounted by
  # storage-box.nix; the 40 GB disk keeps the system and Postgres.
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    port = 2283;
    mediaLocation = "/mnt/immich-library";
    # Only Aurora's: when Aurora is off, new uploads wait for faces and
    # smart search and are caught up later, and smart search itself doesn't
    # answer. Uploads, browsing and the timeline don't need it.
    machine-learning.enable = false;
    # In place of the module's localhost: Immich's default for a fresh
    # install, while a restored database keeps the URL saved in its
    # settings (README.md, "Immich")
    environment.IMMICH_MACHINE_LEARNING_URL = lib.mkForce "http://${auroraIp}:3003";
  };
  custom.tailscale-services.immich.target = "http://127.0.0.1:${toString config.services.immich.port}";

  # Immich starts only with the share mounted, and stops if it goes away,
  # so it never writes into the empty folder beneath
  systemd.services.immich-server = {
    bindsTo = [ "immich-library-mount.service" ];
    after = [ "immich-library-mount.service" ];
  };

  # Aurora keeps a mirror of the library on its external pool
  # (hosts/Aurora/immich-mirror.nix), pulled over Tailscale when it's on.
  # It logs in as this account, which is in Immich's group and so can read
  # the share, and its key can do nothing but a read-only rsync of it.
  users.users.immich-mirror = {
    isSystemUser = true;
    group = "immich-mirror";
    extraGroups = [ config.services.immich.group ];
    # The forced command runs through the login shell
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      ''command="${lib.getExe pkgs.rrsync} -ro ${config.services.immich.mediaLocation}",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIECan97ggvBlpB5UZZq+VYGnvjLh484Rbt2YpAQN5Z7Y immich-mirror@Aurora''
    ];
  };
  users.groups.immich-mirror = { };

  # The daily check and command for Postgres after a glibc update
  # (modules/nixos/postgres-collation.nix)
  custom.postgres-collation = {
    enable = true;
    databaseServices = {
      immich = [ "immich-server.service" ];
      postgres = [ ];
      template1 = [ ];
    };
  };
}
