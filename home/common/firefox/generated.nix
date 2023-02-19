{ buildFirefoxXpiAddon, fetchurl, lib, stdenv }:
  {
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
        platforms = platforms.all;
        };
      };
    "youtube-nonstop" = buildFirefoxXpiAddon {
      pname = "youtube-nonstop";
      version = "0.9.1";
      addonId = "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}";
      url = "https://addons.mozilla.org/firefox/downloads/file/3848483/youtube_nonstop-0.9.1.xpi";
      sha256 = "8340d57622a663949ec1768eb37d47651c809fadf0ffaa5ff546c48fdd28e33d";
      meta = with lib;
      {
        homepage = "https://github.com/lawfx/YoutubeNonStop";
        description = "Tired of getting that \"Video paused. Continue watching?\" confirmation dialog?\nThis extension autoclicks it, so you can listen to your favorite music uninterrupted.\n\nWorking on YouTube and YouTube Music!";
        license = licenses.mit;
        platforms = platforms.all;
        };
      };
    }