{ config, inputs, ... }:
{
  # Homebrew itself is installed and pinned by nix-homebrew; taps come from
  # flake inputs, so `brew update` is disabled and updates arrive with the
  # weekly flake update.
  nix-homebrew = {
    enable = true;
    user = "haoji";
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = false;
    # Take over the existing manual install in /opt/homebrew
    autoMigrate = true;
  };

  # What Homebrew installs, applied with `brew bundle` on every switch
  homebrew = {
    enable = true;
    # Must list the pinned taps, or cleanup would try to untap them
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      # Anything installed with brew but not declared here is removed
      cleanup = "uninstall";
      # Follow the pinned taps; casks marked auto_updates (e.g. Office)
      # are left to their own updater
      upgrade = true;
    };
    # The Microsoft casks are .pkg installers: re-installed over the existing
    # apps, keeping settings; Microsoft AutoUpdate keeps them current.
    # `telegram` is Telegram for macOS, the native Swift app (lighter than the
    # Qt telegram-desktop from nixpkgs); it updates itself.
    casks = [
      # keep-sorted start case=no
      "microsoft-excel"
      "microsoft-outlook"
      "microsoft-powerpoint"
      "microsoft-teams"
      "microsoft-word"
      "telegram"
      # keep-sorted end

      # Not enabled. Self-updating apps with helpers; casks suit them better
      # than nixpkgs. 1Password and Claude are already installed by hand:
      # before uncommenting either, run `brew install --cask --adopt <name>`
      # once so Homebrew takes over the existing app instead of failing on
      # it. Adopt only works while the installed version matches the cask's.
      #"1password"
      #"claude"
      #"orbstack"
    ];

    # `mas`, the App Store command-line tool that masApps below relies on;
    # declared so cleanup doesn't uninstall it
    brews = [ "mas" ];

    # Mac App Store apps (name = App Store ID). Needs the App Store to be
    # signed in. Removing an entry does NOT uninstall the app (a Homebrew
    # Bundle limitation); delete those by hand.
    masApps = {
      # keep-sorted start case=no
      "1Password for Safari" = 1569813296;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      # keep-sorted end
    };
  };
}
