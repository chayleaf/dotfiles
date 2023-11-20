{ config, pkgs, ... }:

{
  imports = [
    ./gui.nix
  ];
  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.librewolf-unwrapped {
      inherit (pkgs.librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
      wmClass = "LibreWolf";
      libName = "librewolf";
      nativeMessagingHosts = with pkgs; [ keepassxc ];
    };
    profiles.chayleaf = {
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
    };
  };
}
