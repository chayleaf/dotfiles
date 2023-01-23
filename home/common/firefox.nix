{ config, pkgs, ... }:
{
  imports = [ ./gui.nix ];
  programs.firefox = {
    enable = true;
    package = pkgs.librewolf;
    extensions = with config.nur.repos.rycee.firefox-addons; [
      youtube-shorts-block
      vimium-c
      search-by-image
      unpaywall
      ublock-origin
      steam-database
      sponsorblock
      rust-search-extension
      return-youtube-dislikes
      protondb-for-steam
      privacy-redirect
      privacy-pass
      noscript
      localcdn
      keepassxc-browser
      i-dont-care-about-cookies
      greasemonkey
      don-t-fuck-with-paste
      cookies-txt
      # also yomichan, maybe i should package it
    ];
    profiles = {
      chayleaf = {};
    };
  };
}
