{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./users.nix
  ];

  # Flakes, unfree, nixpkgs registry pin, weekly GC + store optimisation
  # (modules/nixos/nix-core.nix)
  custom.nix-core = {
    enable = true;
    # Packages cache.nixos.org doesn't have, built and uploaded by CI, so
    # this old dual-core doesn't have to compile them
    ciCache.enable = true;
  };

  # Bootloader. On a Mac, hold Option at power-on to pick the boot entry.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Compressed swap in RAM instead of a swap partition
  zramSwap.enable = true;

  # The hardware profile (flake.nix) assumes the PCIe camera of later
  # MacBooks and would build its unfree driver; this model's is plain USB
  hardware.facetimehd.enable = false;

  # Wi-Fi (Broadcom BCM4331): Broadcom's own driver instead of the kernel's
  # b43, which the hardware profile selects. b43 has no 802.11n support for
  # this card and measured 14 Mbit/s here. The driver is unmaintained and
  # nixpkgs marks it insecure (CVE-2019-9501, CVE-2019-9502), hence the
  # exception; matching by name keeps it valid across kernel updates, which
  # change the package's full name.
  networking.enableB43Firmware = false;
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [
    "b43"
    "bcma"
  ];
  nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";

  networking.hostName = "Tsukuba"; # Must match nixosConfigurations.Tsukuba in flake.nix

  # Enable networking
  networking.networkmanager.enable = true;

  # Everything in Brazilian Portuguese, São Paulo time zone
  # (modules/nixos/locale.nix)
  custom.locale = {
    enable = true;
    defaultLocale = "pt_BR.UTF-8";
  };
  custom.fonts.enable = true;

  # KDE Plasma 6 with SDDM and PipeWire (modules/nixos/plasma.nix)
  custom.plasma = {
    enable = true;
    keyboardLayout = "br";
  };
  # Same layout on the text console
  console.useXkbConfig = true;

  # Straight to the desktop at power-on, no password. KWallet is unlocked by
  # the login password, so with automatic login it would ask for one itself
  # the first time a browser stores something; it's switched off instead.
  services.displayManager.autoLogin = {
    enable = true;
    user = "yuki";
  };
  environment.etc."xdg/kwalletrc".text = ''
    [Wallet]
    Enabled=false
  '';

  # No password after sleep or a closed lid either: this laptop stays at
  # home. These are Plasma's defaults for every user; a setting changed in
  # System Settings takes precedence.
  environment.etc."xdg/kscreenlockerrc".text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';

  # Enable CUPS to print documents.
  services.printing.enable = true;

  hardware.bluetooth.enable = true;

  # For apps installed without going through this config. Flathub has to be
  # added once per machine, which the service below does. Wi-Fi is often
  # not up yet when it runs at boot, so it does nothing once Flathub is
  # there and otherwise retries every minute.
  services.flatpak.enable = true;
  systemd.services.flatpak-add-flathub = {
    description = "Add the Flathub repository to Flatpak";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "1min";
    };
    script = ''
      if flatpak remotes --system --columns=name | grep -qx flathub; then
        exit 0
      fi
      flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Video playback. This GPU decodes H.264 but not the VP9 and AV1 that
  # YouTube prefers, and the CPU can't keep up with those in software (a
  # 1080p60 H.264 clip took 30 s of CPU time to decode in software, 0.3 s
  # on the GPU). So both browsers are told to decode on the GPU and to ask
  # for H.264: Firefox through preferences, Chrome through start-up flags
  # and the h264ify extension.
  programs.firefox = {
    enable = true;
    languagePacks = [ "pt-BR" ];
    preferences = {
      "media.av1.enabled" = false;
      "media.ffmpeg.vaapi.enabled" = true;
      "media.hardware-video-decoding.force-enabled" = true;
      "media.mediasource.vp9.enabled" = false;
    };
  };
  # Only writes browser policies (which Chrome reads too); it doesn't
  # install Chromium
  programs.chromium = {
    enable = true;
    extensions = [ "aleakchihdccplidncghkekgioiakgal" ]; # h264ify
  };

  nixpkgs.overlays = [
    (final: prev: {
      google-chrome = prev.google-chrome.override {
        commandLineArgs = "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL";
      };
    })
  ];

  environment.systemPackages = with pkgs; [
    # keep-sorted start case=no
    google-chrome
    hunspellDicts.pt_BR
    onlyoffice-desktopeditors
    vlc
    # keep-sorted end
  ];

  # Remote administration: Tailscale, and SSH reachable only through it
  # (modules/nixos/ssh-server.nix)
  services.tailscale.enable = true;
  custom.ssh-server.enable = true;

  # Updates itself from the public repo: once a week (or at the next start,
  # if it was off) it builds what master describes and makes it the default
  # for the next boot, so nothing changes under a running session. The
  # previous systems stay in the boot menu.
  system.autoUpgrade = {
    enable = true;
    flake = "github:iedame/nixos-configs#Tsukuba";
    operation = "boot";
    dates = "weekly";
    randomizedDelaySec = "30min";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.11";
}
