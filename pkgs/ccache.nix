{
  pkgs,
  pkgs',
  lib,
  ...
}:

let
  # there are few direct hits with the linux kernel, so use CCACHE_NODIRECT
  # (direct hits are file-based, non-direct are preprocessed file-based)
  ccacheVars = {
    CCACHE_CPP2 = "yes";
    CCACHE_COMPRESS = "1";
    CCACHE_UMASK = "007";
    CCACHE_DIR = "/var/cache/ccache";
    CCACHE_SLOPPINESS = "include_file_mtime,time_macros";
    CCACHE_NODIRECT = "1";
  };

  buildCachedFirefox =
    useSccache: unwrapped:
    (unwrapped.override {
      buildMozillaMach =
        x:
        pkgs'.buildMozillaMach (
          x
          // {
            extraConfigureFlags =
              (x.extraConfigureFlags or [ ])
              ++ lib.toList (if useSccache then "--with-ccache=sccache" else "--with-ccache");
          }
        );
    }).overrideAttrs
      (
        prev:
        if useSccache then
          {
            nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [ pkgs'.sccache ];
            SCCACHE_DIR = "/var/cache/sccache";
            SCCACHE_MAX_FRAME_LENGTH = "104857600";
            RUSTC_WRAPPER = "${pkgs'.sccache}/bin/sccache";
          }
        else
          ccacheVars
          // {
            nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [ pkgs'.ccache ];
          }
      );

  ccacheConfig = ''
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${v}") ccacheVars)}
    if [ ! -d "$CCACHE_DIR" ]; then
      echo "====="
      echo "Directory '$CCACHE_DIR' does not exist"
      echo "Please create it with:"
      echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
      echo "  sudo chown root:nixbld '$CCACHE_DIR'"
      echo "====="
      exit 1
    fi
    if [ ! -w "$CCACHE_DIR" ]; then
      echo "====="
      echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
      echo "Please verify its access permissions"
      echo "====="
      exit 1
    fi
  '';

  overrides = {
    extraConfig = ccacheConfig;
  };

  cacheStdenv = pkgs: pkgs.ccacheStdenv.override overrides;

in
{
  # read by system/modules/ccache.nix
  __dontIncludeCcacheOverlay = true;
  ccacheWrapper = pkgs.ccacheWrapper.override overrides;

  buildFirefoxWithCcache = buildCachedFirefox false;
  buildFirefoxWithSccache = buildCachedFirefox true;

  buildLinuxWithCcache =
    linux:
    linux.override {
      stdenv = cacheStdenv pkgs';
      buildPackages = pkgs'.buildPackages // {
        stdenv = cacheStdenv pkgs'.buildPackages;
      };
    };
}
