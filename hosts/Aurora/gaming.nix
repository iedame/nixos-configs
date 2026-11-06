{ pkgs, ... }:

{
  # Enable ProtonTricks and GameMode
  programs.steam.protontricks.enable = true;
  programs.gamemode.enable = true;

  # Install Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    gamescopeSession.enable = true;
  };

  # Enable ASF
  services.archisteamfarm = {
    enable = true;
    web-ui.enable = true;
  };

  # Jagex Launcher + RuneLite, with the shim that makes "Play" work on NixOS
  # (the runescape module of github.com/iedame/nur-packages)
  programs.runescape = {
    enable = true;
    users = [ "haoji" ];
  };

  # AppImages run in appimage-run's set of common libraries (the RuneScape
  # module turns this on, with binfmt). Lichii's AppImage (a Switch 2
  # emulator, run by the games account) bundles libgcrypt but not
  # libgpg-error, which that needs and the set lacks.
  programs.appimage.package = pkgs.appimage-run.override {
    extraPkgs = pkgs: [ pkgs.libgpg-error ];
  };

  environment.systemPackages = with pkgs; [
    # keep-sorted start case=no
    adwsteamgtk
    eden
    heroic
    lutris
    mangohud
    ns-usbloader
    protonup-qt
    ryubing
    wineWow64Packages.stable
    xdotool
    xwininfo
    yad
    # keep-sorted end
  ];
}
