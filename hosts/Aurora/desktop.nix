{ pkgs, ... }:

{
  # KDE Plasma 6 with SDDM and PipeWire, US layout (modules/nixos/plasma.nix)
  custom.plasma.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable Flatpak
  services.flatpak.enable = true;

  services.hardware.openrgb.enable = true;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # Enable I2C for ddcutil (monitor display control)
  hardware.i2c.enable = true;

  services.blueman.enable = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Install Thunderbird
  programs.thunderbird.enable = true;

  # Install 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "haoji" ];
  };

  # Desktop applications
  environment.systemPackages = with pkgs; [
    # keep-sorted start case=no
    ddcui
    element-desktop
    filezilla
    gnome-disk-utility
    gparted
    gsmartcontrol
    jetbrains.idea
    keepassxc
    onlyoffice-desktopeditors
    openrgb
    planify
    pomodoro-gtk
    proton-authenticator
    proton-pass
    proton-vpn
    resources
    spotify
    telegram-desktop
    vlc
    xournalpp
    # keep-sorted end
  ];
}
