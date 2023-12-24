{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./gui.nix
  ];
  home.file.".mozilla/firefox/profiles.ini".target = ".librewolf/profiles.ini";
  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.librewolf-unwrapped {
      inherit (pkgs.librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
      wmClass = "LibreWolf";
      libName = "librewolf";
      nativeMessagingHosts = with pkgs; [ keepassxc ];
    };
    profiles.chayleaf = lib.mkMerge [
      {
        extensions = (with config.nur.repos.rycee.firefox-addons; [
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
          youtube-shorts-block
        ]) ++ (with pkgs.firefoxAddons; [
          fastforwardteam
          middle-mouse-button-scroll
          rikaitan
          youtube-nonstop
        ]);
        settings = lib.mkIf config.phone.enable {
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
      })
    ];
  };
}
