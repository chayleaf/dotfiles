{ config
, pkgs
, lib
, ...
}:

{
  imports = [ ./gui.nix ];

  programs.librewolf = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.librewolf-unwrapped {
      inherit (pkgs.librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
      wmClass = "LibreWolf";
      libName = "librewolf";
      nativeMessagingHosts = with pkgs; [ keepassxc ];
    };
    profiles.other.id = 1;
    profiles.other.bookmarks = [{
          name = "bookmarklets";
          toolbar = true;
          bookmarks = [
            {
              name = "example.com";
              url = "https://example.com";
            }
          ];
        }];
    profiles.chayleaf = lib.mkMerge [
      {
        extensions = (with pkgs.nur.repos.rycee.firefox-addons; [
          cookies-txt
          don-t-fuck-with-paste
          greasemonkey
          keepassxc-browser
          libredirect
          localcdn
          noscript
          privacy-pass
          protondb-for-steam
          return-youtube-dislikes
          rust-search-extension
          search-by-image
          sponsorblock
          steam-database
          ublock-origin
          unpaywall
          vimium-c
          yomitan
          youtube-shorts-block
        ]) ++ (with pkgs.firefoxAddons; [
          fastforwardteam
          youtube-nonstop
        ]);
        search.default = "search.pavluk.org";
        search.privateDefault = "search.pavluk.org";
        search.force = true;
        search.engines."search.pavluk.org" = {
          name = "search.pavluk.org";
          description = "SearXNG is a metasearch engine that respects your privacy.";
          queryCharset = "UTF-8";
          searchForm = "https://search.pavluk.org/search";
          iconURL = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI5Mm1tIiBoZWlnaHQ9IjkybW0iIHZpZXdCb3g9IjAgMCA5MiA5MiI+PGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTQwLjkyMSAtMTcuNDE3KSI+PGNpcmNsZSBjeD0iNzUuOTIxIiBjeT0iNTMuOTAzIiByPSIzMCIgc3R5bGU9ImZpbGw6bm9uZTtmaWxsLW9wYWNpdHk6MTtzdHJva2U6IzMwNTBmZjtzdHJva2Utd2lkdGg6MTA7c3Ryb2tlLW1pdGVybGltaXQ6NDtzdHJva2UtZGFzaGFycmF5Om5vbmU7c3Ryb2tlLW9wYWNpdHk6MSIvPjxwYXRoIGQ9Ik02Ny41MTUgMzcuOTE1YTE4IDE4IDAgMCAxIDIxLjA1MSAzLjMxMyAxOCAxOCAwIDAgMSAzLjEzOCAyMS4wNzgiIHN0eWxlPSJmaWxsOm5vbmU7ZmlsbC1vcGFjaXR5OjE7c3Ryb2tlOiMzMDUwZmY7c3Ryb2tlLXdpZHRoOjU7c3Ryb2tlLW1pdGVybGltaXQ6NDtzdHJva2UtZGFzaGFycmF5Om5vbmU7c3Ryb2tlLW9wYWNpdHk6MSIvPjxyZWN0IHdpZHRoPSIxOC44NDYiIGhlaWdodD0iMzkuOTYzIiB4PSIzLjcwNiIgeT0iMTIyLjA5IiByeT0iMCIgc3R5bGU9Im9wYWNpdHk6MTtmaWxsOiMzMDUwZmY7ZmlsbC1vcGFjaXR5OjE7c3Ryb2tlOm5vbmU7c3Ryb2tlLXdpZHRoOjg7c3Ryb2tlLW1pdGVybGltaXQ6NDtzdHJva2UtZGFzaGFycmF5Om5vbmU7c3Ryb2tlLW9wYWNpdHk6MSIgdHJhbnNmb3JtPSJyb3RhdGUoLTQ2LjIzNSkiLz48L2c+PC9zdmc+";
          urls = [
            { "params" = [ { "name" = "q"; "value" = "{searchTerms}"; } ];
              "rels" = [ "results" ];
              "template" = "https://search.pavluk.org/search";
              "method" = "POST"; }
            { "params" = [ ];
              "rels" = [ "suggestions" ];
              "template" = "https://search.pavluk.org/autocompleter?q={searchTerms}";
              "type" = "application/x-suggestions+json";
              "method" = "POST"; }
          ];
        };
        settings = let
          langs = [ "ar" "el" "he" "ja" "ko" "th" "x-armn" "x-beng" "x-cans" "x-cyrillic" "x-devanagari"
                    "x-ethi" "x-geor" "x-gujr" "x-guru" "x-khmr" "x-knda" "x-math" "x-mlym" "x-orya"
                    "x-sinh" "x-tamil" "x-telu" "x-tibt" "x-unicode" "x-western" "zh-CN" "zh-HK" "zh-TW" ];
          genFonts = prefix: func:
            lib.genAttrs
              (map (lang: "font.name.${prefix}.${lang}") langs)
              (s: func (lib.removePrefix "font.name.${prefix}." s));
          notoFamilies = {
            ar = "Arabic"; x-armn = "Armenian"; x-beng = "Bengali"; x-cans = "Canadian Aboriginal";
            ja = "CJK JP"; ko = "CJK KR"; zh-CN = "CJK SC"; zh-HK = "CJK HK"; zh-TW = "CJK TC";
            /* cyrillic = "Cyrillic"; */ x-devanagari = "Devanagari"; /* el = "Greek"; */
            x-ethi = "Ethiopic"; x-geor = "Georgian"; x-gujr = "Gujarati"; x-guru = "Gurmukhi";
            he = "Hebrew"; x-khmr = "Khmer"; x-knda = "Kannada"; x-math = "Math"; x-mlym = "Malayalam";
            x-orya = "Oriya"; x-sinh = "Sinhala"; x-tamil = "Tamil"; x-telu = "Telugu"; th = "Thai";
            x-tibt = "Tibetan"; /* x-unicode = "Other Writing Systems"; x-western = "Latin"; */
          };
        in genFonts "monospace" (_: "Noto Sans Mono")
        // genFonts "sans-serif" (lang: if notoFamilies?${lang} then "Noto Sans ${notoFamilies.${lang}}" else "Noto Sans")
        // genFonts "serif" (lang: if notoFamilies?${lang} then "Noto Serif ${notoFamilies.${lang}}" else "Noto Serif")
        // {
          "font.name.monospace.ja" = "Noto Sans Mono CJK JP";
          "font.name.monospace.ko" = "Noto Sans Mono CJK KR";
          "font.name.monospace.zh-CN" = "Noto Sans Mono CJK SC";
          "font.name.monospace.zh-HK" = "Noto Sans Mono CJK HK";
          "font.name.monospace.zh-TW" = "Noto Sans Mono CJK TC";
          "font.name.serif.ar" = "Noto Sans Arabic";
          "font.name.serif.x-cans" = "Noto Sans Canadian Aboriginal";
          "font.name.serif.x-math" = "Noto Sans Math";
          "font.name.serif.x-orya" = "Noto Sans Oriya";

          # user-facing tweaks
          "browser.quitShortcut.disabled" = true;
          "browser.search.suggest.enabled" = true;
          "general.autoScroll" = true;
          "middlemouse.paste" = false;
          "spellchecker.dictionary_path" = pkgs.symlinkJoin {
            name = "firefox-hunspell-dicts";
            paths = with pkgs.hunspellDicts; [ en-us-large ru-ru ];
          };
          "widget.content.allow-gtk-dark-theme" = true;

          # user agent and overall behavioral tweaks
          "gfx.webrender.all" = true;
          "general.useragent.compatMode.firefox" = true;
          "image.jxl.enabled" = true;
          "noscript.sync.enabled" = true;
          "privacy.donottrackheader.enabled" = true;
          "webgl.disabled" = false;
          "xpinstall.signatures.required" = false;

          # privacy tweaks
          "browser.contentblocking.category" = "strict";
          "intl.accept_languages" = "en-US, en";
          "javascript.use_us_english_locale" = true;
          "privacy.clearOnShutdown.cache" = false;
          "privacy.clearOnShutdown.cookies" = false;
          "privacy.clearOnShutdown.downloads" = false;
          "privacy.clearOnShutdown.formdata" = false;
          "privacy.clearOnShutdown.history" = false;
          "privacy.clearOnShutdown.offlineApps" = false;
          "privacy.clearOnShutdown.sessions" = false;
          "privacy.fingerprintingProtection" = true;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
        };
      }
      (let
        concatFiles = dir:
          builtins.concatStringsSep ""
            (map
              (k: lib.optionalString (!lib.hasInfix ".before-ff" k) (builtins.readFile "${dir}/${k}"))
              (builtins.attrNames (builtins.readDir dir)));
      in lib.mkIf config.phone.enable {
        userChrome =
          concatFiles "${pkgs.mobile-config-firefox}/etc/mobile-config-firefox/common"
          + concatFiles "${pkgs.mobile-config-firefox}/etc/mobile-config-firefox/userChrome";
        userContent =
          concatFiles "${pkgs.mobile-config-firefox}/etc/mobile-config-firefox/common"
          + concatFiles "${pkgs.mobile-config-firefox}/etc/mobile-config-firefox/userContent";

        settings = {
          "dom.w3c.touch_events.enabled" = true;
          "apz.allow_zooming" = true;
          "apz.allow_double_tap_zooming" = true;
          "dom.w3c_touch_events.legacy_apis.enabled" = true;
          "browser.tabs.inTitlebar" = 1;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.urlbar.clickSelectsAll" = true;
          "toolkit.cosmeticAnimations.enabled" = false;
          "browser.download.animateNotifications" = false;
        };
      })
    ];
  };
}
