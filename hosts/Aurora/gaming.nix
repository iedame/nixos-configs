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
  # (modules/nixos/runescape.nix)
  programs.runescape = {
    enable = true;
    users = [ "haoji" ];
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
