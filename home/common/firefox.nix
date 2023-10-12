{ config, pkgs, ... }:

/*let firefoxWithCcache = ({ useSccache, firefox-unwrapped }:
  (firefox-unwrapped.override {
    buildMozillaMach = (x: (pkgs.buildMozillaMach (x // {
      extraConfigureFlags = x.extraConfigureFlags ++ [
        (if useSccache then "--with-ccache=sccache" else "--with-ccache")
      ];
    })));
  }).overrideAttrs (prev: if useSccache then {
    nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.sccache ];
    SCCACHE_DIR = "/var/cache/sccache";
    SCCACHE_MAX_FRAME_LENGTH = "104857600";
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
  } else {
    nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.ccache ];
    CCACHE_CPP2 = "yes";
    CCACHE_COMPRESS = "1";
    CCACHE_UMASK = "007";
    CCACHE_DIR = "/var/cache/ccache";
  })
); in*/

{
  imports = [
    ./gui.nix
  ];
  programs.firefox = {
    enable = true;
    package =
      pkgs.wrapFirefox pkgs.librewolf-unwrapped {
        inherit (pkgs.librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
        wmClass = "LibreWolf";
        libName = "librewolf";
        # TODO: keepass in extraNativeMessagingHosts?
      };
    profiles = {
      chayleaf = {
        extensions = with config.nur.repos.rycee.firefox-addons; [
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
        ] ++ (with pkgs.firefox-addons; [
          fastforwardteam
          middle-mouse-button-scroll
          rikaitan
          youtube-nonstop
        ]);
      };
    };
  };
}
