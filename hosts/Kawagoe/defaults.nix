# macOS settings. Most were captured from this Mac (2026-10-09) with
# `defaults export`; a few Finder ones were chosen afterwards. Anything left
# at Apple's default isn't listed.
# Applied on every switch, so changes made in System Settings get reverted:
# change them here instead.
{ ... }:
{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      # Natural scrolling off
      "com.apple.swipescrolldirection" = false;
      # Play feedback sound when changing volume
      "com.apple.sound.beep.feedback" = 1;
    };

    dock = {
      tilesize = 67;
      show-recents = false;
      magnification = false;
      # Minimised windows go into their app's icon instead of the Dock's
      # right side
      minimize-to-application = true;
      # Plain shrink animation instead of the genie warp
      mineffect = "scale";
      # Hidden apps (Cmd-H) get a translucent icon
      showhidden = true;
      # Hot corner, top left: Lock Screen (1 = disabled, 13 = Lock Screen)
      wvous-tl-corner = 13;
      # Pinned apps, left to right. Apps not listed here get unpinned on the
      # next switch, so add new ones here rather than by dragging.
      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Applications/System Settings.app"
        "/System/Applications/App Store.app"
        # The real Safari; /Applications/Safari.app is a symlink to it and
        # would show in the Dock with an alias arrow
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
        "/Applications/Firefox.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Contacts.app"
        "/System/Applications/Reminders.app"
        "/System/Applications/Notes.app"
        "/Users/haoji/Applications/Home Manager Apps/Alacritty.app"
        "/Applications/Claude.app"
        "/Applications/Antigravity.app"
        "/Applications/Nix Apps/BBEdit.app"
        "/Applications/Nix Apps/Element.app"
        "/Applications/Telegram.app"
      ];
      # Folders on the right side of the Dock
      persistent-others = [
        {
          folder = {
            path = "/Applications";
            arrangement = "name";
            displayas = "folder";
            showas = "automatic";
          };
        }
        {
          folder = {
            path = "/Users/haoji/Downloads";
            arrangement = "date-added";
            displayas = "folder";
            showas = "fan";
          };
        }
      ];
    };

    # Screenshots go here instead of the Desktop (folder is created by
    # home-manager, see users/haoji/default.nix)
    screencapture.location = "~/Pictures/Screenshots";

    finder = {
      # List view in new windows
      FXPreferredViewStyle = "Nlsv";
      # New Finder windows open to the home folder
      NewWindowTarget = "Home";
      ShowStatusBar = true;
      # Folder breadcrumbs at the bottom of windows
      ShowPathbar = true;
      # Full path (/Users/haoji/...) in the window title
      _FXShowPosixPathInTitle = true;
      # Folders above files when sorting by name, in windows and on the Desktop
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      # Search the current folder instead of the whole Mac
      FXDefaultSearchScope = "SCcf";
      # Delete Trash items automatically after 30 days
      FXRemoveOldTrashItems = true;
      ShowHardDrivesOnDesktop = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowMountedServersOnDesktop = true;
    };

    WindowManager = {
      # Hide desktop items while Stage Manager is on
      HideDesktop = true;
      StandardHideWidgets = false;
    };

    menuExtraClock = {
      ShowAMPM = true;
      ShowDayOfWeek = true;
      # 0: show the date when space allows
      ShowDate = 0;
    };

    # Settings without a dedicated nix-darwin option
    CustomUserPreferences = {
      NSGlobalDomain = {
        "com.apple.mouse.scaling" = 3.0;
        "com.apple.scrollwheel.scaling" = 1.7;
        AppleMiniaturizeOnDoubleClick = false;
      };
      # Don't litter network shares and USB drives with .DS_Store files
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
    };
  };
}
