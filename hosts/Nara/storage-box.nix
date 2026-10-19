{
  config,
  lib,
  pkgs,
  ...
}:
let
  mountPoint = "/mnt/immich-library";
  credentials = config.age.secrets."immich-library-smb".path;
in
{
  # Immich's library lives on a sub-account of the Hetzner storage box that
  # also holds Aurora's Borg backups, in the same data centre, mounted over
  # SMB. The sub-account sees only its own folder (immich-library), and the
  # Borg repositories are other sub-accounts, out of Nara's reach. It accepts
  # connections from inside Hetzner's network only.
  #
  # Not a fileSystems entry: the share's address holds the account name,
  # which stays out of this repository. It comes from the credentials file
  # (an agenix secret, secrets.nix): //<username>.your-storagebox.de/<username>.
  boot.supportedFilesystems = [ "cifs" ];

  systemd.services.immich-library-mount = {
    description = "Mount Immich's library from the storage box over SMB";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # The network may be up before the box answers; try again
      Restart = "on-failure";
      RestartSec = 30;
      ExecStop = "${pkgs.util-linux}/bin/umount ${mountPoint}";
    };
    script = ''
      user=$(sed -n 's/^username=//p' ${credentials})
      mkdir -p ${mountPoint}
      mountpoint -q ${mountPoint} && exit 0
      # seal: SMB3 encryption, as the traffic crosses Hetzner's network.
      # The share has no Unix owners, so every file shows as Immich's.
      ${lib.getExe' pkgs.cifs-utils "mount.cifs"} "//$user.your-storagebox.de/$user" ${mountPoint} \
        -o credentials=${credentials},seal,iocharset=utf8,uid=immich,gid=immich,file_mode=0640,dir_mode=0750
    '';
  };
}
