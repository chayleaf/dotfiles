{ buildFirefoxXpiAddon, fetchurl, lib, stdenv }:
  {
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