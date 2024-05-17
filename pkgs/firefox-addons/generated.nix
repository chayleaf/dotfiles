{ buildFirefoxXpiAddon, fetchurl, lib, stdenv }:
  {
    "fastforwardteam" = buildFirefoxXpiAddon {
      pname = "fastforwardteam";
      version = "0.2383";
      addonId = "addon@fastforward.team";
      url = "https://addons.mozilla.org/firefox/downloads/file/4258067/fastforwardteam-0.2383.xpi";
      sha256 = "eec6328df3df1afe2cb6a331f6907669d804235551ea766d48655f8f831caf28";
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
    "rikaitan" = buildFirefoxXpiAddon {
      pname = "rikaitan";
      version = "24.5.21.0";
      addonId = "tatsu@autistici.org";
      url = "https://addons.mozilla.org/firefox/downloads/file/4291845/rikaitan-24.5.21.0.xpi";
      sha256 = "a2a94d88af04023f14daaafda1f6ca7a7197f2ab92ada08ee2e9e4292d57a391";
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