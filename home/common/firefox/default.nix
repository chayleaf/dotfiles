{ config, pkgs, lib, ... }:
let firefoxWithCcache = ({ useSccache, firefox-unwrapped }:
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
); in {
  imports = [
    ../gui.nix
  ];
  programs.firefox = {
    enable = true;
    package =
      let librewolf-unwrapped = firefoxWithCcache {
          useSccache = true;
          firefox-unwrapped = pkgs.librewolf-unwrapped.overrideAttrs (prev: {
            MOZ_REQUIRE_SIGNING = "";
          });
        };
      in pkgs.wrapFirefox librewolf-unwrapped {
        inherit (librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
        wmClass = "LibreWolf";
        libName = "librewolf";
        # TODO: keepass in extraNativeMessagingHosts?
      };
    profiles = {
      chayleaf = {
        extensions =
          with config.nur.repos.rycee.firefox-addons;
          let sources = (import ../../_sources/generated.nix {
            inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
          });
          # addons.mozilla.org's version is horribly outdated for whatever reason
          # I guess the extension normally autoupdates by itself?
          # this is an unsigned build
          yomichan = pkgs.stdenvNoCC.mkDerivation {
            inherit (sources.yomichan) pname version src;
            preferLocalBuild = true;
            allowSubstitutes = true;
            buildCommand = ''
              dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
              mkdir -p "$dst"
              install -v -m644 "$src" "$dst/alex.testing@foosoft.net.xpi"
            '';
            meta = with lib; {
              homepage = "https://foosoft.net/projects/yomichan";
              description = "Yomichan turns your browser into a tool for building Japanese language literacy by helping you to decipher texts which would be otherwise too difficult tackle. It features a robust dictionary with EPWING and flashcard creation support.";
              license = licenses.gpl3;
              platforms = platforms.all;
            };
          };
          fastforward = pkgs.stdenvNoCC.mkDerivation {
            inherit (sources.fastforward) pname version src;
            preferLocalBuild = true;
            allowSubstitutes = true;
            buildCommand = ''
              dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
              mkdir -p "$dst"
              install -v -m644 "$src" "$dst/addon@fastforward.team"
            '';
            meta = with lib; {
              homepage = "https://fastforward.team";
              description = "Don't waste time with compliance. Use FastForward to skip annoying URL \"shorteners\"";
              license = licenses.unlicense;
              platforms = platforms.all;
            };
          };
          in with (import ./generated.nix {
            inherit lib stdenv fetchurl buildFirefoxXpiAddon;
          });
        [
          # from rycee's repo
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
          libredirect
          privacy-pass
          noscript
          localcdn
          keepassxc-browser
          i-dont-care-about-cookies
          greasemonkey
          don-t-fuck-with-paste
          cookies-txt
          fastforward

          # my packages
          yomichan
          youtube-nonstop
          middle-mouse-button-scroll
        ];
      };
    };
  };
}
