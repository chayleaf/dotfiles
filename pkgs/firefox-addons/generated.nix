{ buildFirefoxXpiAddon, fetchurl, lib, stdenv }:
  {
    "fastforwardteam" = buildFirefoxXpiAddon {
      pname = "fastforwardteam";
      version = "0.2334";
      addonId = "addon@fastforward.team";
      url = "https://addons.mozilla.org/firefox/downloads/file/4177101/fastforwardteam-0.2334.xpi";
      sha256 = "d790219622469f08316b41c0d01abf2b584a37fa87b45666a74bd30cffb95ed0";
      meta = with lib;
      {
        homepage = "https://fastforward.team";
        description = "Don't waste time with compliance. Use FastForward to skip annoying URL \"shorteners\".";
        mozPermissions = [
          "alarms"
          "storage"
          "webNavigation"
          "tabs"
          "declarativeNetRequestWithHostAccess"
          "<all_urls>"
          ];
        platforms = platforms.all;
        };
      };
    "middle-mouse-button-scroll" = buildFirefoxXpiAddon {
      pname = "middle-mouse-button-scroll";
      version = "0.3.2";
      addonId = "{b687f6ef-3299-4a75-8279-8b1c30dfcc9d}";
      url = "https://addons.mozilla.org/firefox/downloads/file/3505309/middle_mouse_button_scroll-0.3.2.xpi";
      sha256 = "d21d29b29a7bd3fae5407d995737c4c41d66daf73729b88ad39d149223362412";
      meta = with lib;
      {
        homepage = "https://github.com/StoyanDimitrov/middle-mouse-button-scroll";
        description = "Scroll fast or precise through long documents with pressed middle mouse button";
        mozPermissions = [ "*://*/*" ];
        platforms = platforms.all;
        };
      };
    "rikaitan" = buildFirefoxXpiAddon {
      pname = "rikaitan";
      version = "24.1.22.0";
      addonId = "tatsu@autistici.org";
      url = "https://addons.mozilla.org/firefox/downloads/file/4224979/rikaitan-24.1.22.0.xpi";
      sha256 = "7df217a68077d45b9f41fe0170193c9224abc2a543c121429ebef4e7e857b0df";
      meta = with lib;
      {
        homepage = "https://github.com/Ajatt-Tools/rikaitan";
        description = "Japanese dictionary with Anki integration and flashcard creation support.";
        license = licenses.gpl3;
        mozPermissions = [
          "storage"
          "clipboardWrite"
          "unlimitedStorage"
          "declarativeNetRequest"
          "scripting"
          "http://*/*"
          "https://*/*"
          "file://*/*"
          ];
        platforms = platforms.all;
        };
      };
    "youtube-nonstop" = buildFirefoxXpiAddon {
      pname = "youtube-nonstop";
      version = "0.9.2";
      addonId = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
      url = "https://addons.mozilla.org/firefox/downloads/file/4187690/youtube_nonstop-0.9.2.xpi";
      sha256 = "7659d180f76ea908ea81b84ed9bdd188624eaaa62b88accbe6d8ad4e8caeff38";
      meta = with lib;
      {
        homepage = "https://github.com/lawfx/YoutubeNonStop";
        description = "Tired of getting that \"Video paused. Continue watching?\" confirmation dialog?\nThis extension autoclicks it, so you can listen to your favorite music uninterrupted.\n\nWorking on YouTube and YouTube Music!";
        license = licenses.mit;
        mozPermissions = [
          "https://www.youtube.com/*"
          "https://music.youtube.com/*"
          ];
        platforms = platforms.all;
        };
      };
    }