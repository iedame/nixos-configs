{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./ssh.nix
    ./users.nix
    ./desktop.nix
    ./graphics.nix
    ./gaming.nix
    ./services.nix
    ./backup.nix
  ];

  # Flakes, unfree, nixpkgs registry pin, weekly GC + store optimisation
  # (modules/nixos/nix-core.nix)
  custom.nix-core = {
    enable = true;
    # The few packages this host would otherwise compile (Paperless and its
    # OCR stack, mostly), built and uploaded by CI
    ciCache.enable = true;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "12460081";

  # ZFS Automatic scrubbing
  services.zfs.autoScrub.enable = true;

  # SMART monitoring of all five drives, plus an hourly check that fails,
  # and so shows up in the health reports below, when a drive or a pool is
  # in trouble (modules/nixos/disk-health.nix)
  custom.disk-health.enable = true;

  # Automatically import ZFS pools on boot
  boot.zfs.extraPools = [
    "backup-pool"
    "external-pool"
  ];

  networking.hostName = "Aurora"; # Must match nixosConfigurations.Aurora in flake.nix

  # Enable networking
  networking.networkmanager.enable = true;

  # São Paulo time zone, English messages, pt_BR formats
  # (modules/nixos/locale.nix)
  custom.locale.enable = true;
  custom.fonts.enable = true;

  # Install Neovim
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Command-line tools and development; desktop apps are in desktop.nix and
  # gaming ones in gaming.nix
  environment.systemPackages = with pkgs; [
    # keep-sorted start case=no
    curl
    ddcutil
    fastfetch
    gh
    ghostscript
    git
    hydra-check
    img2pdf
    jq
    libplist
    nixpkgs-review
    nvd
    podman-compose
    rclone
    restic
    ripgrep
    smartmontools
    traceroute
    unrar
    vim
    wget
    yt-dlp
    # keep-sorted end
  ];

  # Enable Tailscale service
  services.tailscale.enable = true;

  # Reports this host's health to an Uptime Kuma push monitor on one of the
  # Oracle servers, which alerts when a unit fails here. This machine is
  # often off, so the monitor's heartbeat interval is set to weeks: silence
  # is normal, a failure is not (modules/nixos/heartbeat.nix). The
  # monitor's push URL is an agenix secret (secrets.nix).
  custom.heartbeat = {
    enable = true;
    urlFile = config.age.secrets."heartbeat-url".path;
  };

  # Per-interface ports are opened where the service is defined (ssh.nix,
  # services.nix).
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
