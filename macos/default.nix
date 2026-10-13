# macOS itself: system preferences, Dock, Finder, keyboard, login. Browse every option: https://nix-darwin.github.io/nix-darwin/manual/
# Find the key behind a setting you changed in System Settings with:
#   defaults read > before.txt; (change it); defaults read > after.txt; diff before.txt after.txt
{ user, ... }:
{
  imports = [ ./text-replacements.nix ];

  # Touch ID for sudo (survives macOS updates, unlike editing /etc/pam.d/sudo).
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyleSwitchesAutomatically = true; # light/dark follows time of day
      ApplePressAndHoldEnabled = false; # key repeat instead of the accent popup
      KeyRepeat = 2; # fastest repeat
      InitialKeyRepeat = 15; # short delay before repeat
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false; # straight quotes (sane for code)
      NSAutomaticDashSubstitutionEnabled = false;
      NSDocumentSaveNewDocumentsToCloud = false; # save to disk, not iCloud, by default
      "com.apple.swipescrolldirection" = true; # "natural" scrolling
    };

    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false; # don't reorder Spaces by recent use
      tilesize = 48;
      minimize-to-application = true;
      persistent-apps = [
        "/Applications/Spotify.app"
        "/Applications/1Password.app"
        "/Applications/Zed.app"
        "/System/Applications/Utilities/Terminal.app"
      ];
      # Hot corners: 1 = disabled, 2 = Mission Control, 4 = Desktop, 13 = Lock Screen
      wvous-br-corner = 4;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      FXDefaultSearchScope = "SCcf"; # search the current folder
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      NewWindowTarget = "Home";
    };

    trackpad = {
      Clicking = true; # tap to click
      TrackpadThreeFingerDrag = true;
    };

    screencapture = {
      location = "/Users/${user.name}/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    loginwindow.GuestEnabled = false;

    # Anything without a first-class option goes here as raw `defaults` domains.
    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        # No .DS_Store files on network or USB volumes.
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      "com.apple.universalaccess" = {
        closeViewScrollWheelToggle = true; # Enable modifier + scroll zoom.
        HIDScrollZoomModifierMask = 262144; # Control (1 << 18).
      };
    };
  };

  # Text replacements (System Settings → Keyboard → Text Replacements): type the shortcut,
  # then a space. Works in native apps (Notes, Mail, Messages, Safari), not terminals or Zed.
  macos.textReplacements = {
    "<-" = "←";
    "->" = "→";
    "-^" = "↑";
    "-v" = "↓";
  };

  # Keyboard: Caps Lock → Escape.
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # The folder screenshots are saved to (see screencapture.location above).
  hm =
    { lib, ... }:
    {
      home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "$HOME/Pictures/Screenshots"
      '';
    };
}
