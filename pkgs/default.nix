{ pkgs
, lib
, nur
, nix-gaming
, pkgs' ? pkgs
, ... }:
let
  inherit (pkgs) callPackage;
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
  };
  armTrustedFirmwareBpiR3 = { bootDevice, uboot ? null }: pkgs.buildArmTrustedFirmware rec {
    # TODO: nvfetcherify this
    src = pkgs.fetchFromGitHub {
      owner = "frank-w";
      repo = "u-boot";
      rev = "c30a1caf8274af67bf31f3fb5abc45df5737df36";
      hash = "sha256-pW2yytXRIFEIbG1gnuXq8TiLe/Eew7zESe6Pijh2qVk=";
    };
    patches = [ ./bpi-r3-atf-backport-mkimage-support.patch ];
    extraMakeFlags = assert builtins.elem bootDevice [
      "nor" "snand" "spim-nand" "emmc" "sdmmc" "ram"
    ]; [
      "BOOT_DEVICE=${bootDevice}"
      "DRAM_USE_DDR4=1"
      "USE_MKIMAGE=1"
      "MKIMAGE=${pkgs.ubootTools}/bin/mkimage"
      "all"
      "fip"
    ] ++ lib.optionals (uboot != null) [
      "BL33=${uboot}/u-boot.bin"
    ];
    extraMeta.platforms = [ "aarch64-linux" ];
    platform = "mt7986";
    filesToInstall = [
      "build/${platform}/release/bl2.img"
      "build/${platform}/release/fip.bin"
    ];
    nativeBuildInputs = with pkgs; [ /*pkgsCross.arm-embedded.stdenv.cc*/ dtc ];
  };
  # sd/emmc
  # -- CONFIG_USE_BOOTCOMMAND/CONFIG_BOOTCOMMAND - distroboot stuff (override default boot command)
  # -- CONFIG_BOOTDELAY - autoboot timeout
  # CONFIG_BOOTSTD_DEFAULTS - stdboot stuff
  # CONFIG_BOOTSTD_BOOTCOMMAND - might be? an alternative to CONFIG_BOOTCOMMAND
  # CONFIG_DEFAULT_FDT_FILE - compatibility with nixos
  # CONFIG_DISTRO_DEFAULTS - surely this won't hurt, it adds autocomplete and stuff and doesn't weight much in the large scale of things
  # CONFIG_SYS_BOOTM_LEN - increase max initrd? size
  # CONFIG_ZSTD - allow zstd initrd
  ubootConfig = storage: ''
    CONFIG_AUTOBOOT=y
    CONFIG_BOOTCOMMAND="${builtins.replaceStrings [ "\n" ] [ "; " ] ''
        setenv boot_prefixes /@boot/ /@/ /boot/ /
        run distro_bootcmd
    ''};"
    CONFIG_BOOTSTD_DEFAULTS=y
    CONFIG_BOOTSTD_FULL=y
    CONFIG_CMD_BTRFS=y
    CONFIG_CMD_CAT=y
    CONFIG_DEFAULT_FDT_FILE="mediatek/mt7986a-bananapi-bpi-r3.dtb"
    CONFIG_DISTRO_DEFAULTS=y
    CONFIG_ENV_IS_NOWHERE=y
    CONFIG_FS_BTRFS=y
    CONFIG_SYS_BOOTM_LEN=0x6000000
    CONFIG_USE_BOOTCOMMAND=y
    CONFIG_ZSTD=y
  '';
  ubootVersion = "2023.07-rc3";
  ubootSrc = pkgs.fetchurl {
    url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${ubootVersion}.tar.bz2";
    hash = "sha256-QuwINnS9MPpMFueMP19FPAjZ9zdZWne13aWVrDoJ2C8=";
  };
in

rec {
  osu-lazer-bin = nix-gaming.osu-lazer-bin;
  clang-tools_latest = pkgs.clang-tools_16;
  clang_latest = pkgs.clang_16;
  home-daemon = callPackage ./home-daemon { };
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
  lalrpop = callPackage ./lalrpop { };
  # pin version
  looking-glass-client = pkgs.looking-glass-client.overrideAttrs (old: {
    version = "B6";
    src = pkgs.fetchFromGitHub {
      owner = "gnif";
      repo = "LookingGlass";
      rev = "B6";
      sha256 = "sha256-6vYbNmNJBCoU23nVculac24tHqH7F4AZVftIjL93WJU=";
      fetchSubmodules = true;
    };
  });
  maubot = callPackage ./maubot.nix { };
  pineapplebot = callPackage ./pineapplebot.nix { };
  proton-ge = pkgs.stdenvNoCC.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
  # system76-scheduler = callPackage ./system76-scheduler.nix { };
  techmino = callPackage ./techmino { };

  ubootBpiR3Sd = pkgs.buildUBoot {
    defconfig = "mt7986a_bpir3_sd_defconfig";
    extraConfig = ubootConfig "sd";
    src = ubootSrc;
    version = ubootVersion;
    extraMeta.platforms = [ "aarch64-linux" ];
    # https://github.com/nakato/nixos-bpir3-example/blob/main/pkgs/uboot/mt7986-default-bootcmd.patch
    patches = [ ./mt7986-default-bootcmd.patch ];
    filesToInstall = [ "u-boot.bin" ];
  };
  ubootBpiR3Emmc = pkgs.buildUBoot {
    defconfig = "mt7986a_bpir3_emmc_defconfig";
    extraConfig = ubootConfig "emmc";
    src = ubootSrc;
    version = ubootVersion;
    extraMeta.platforms = [ "aarch64-linux" ];
    patches = [ ./mt7986-default-bootcmd.patch ];
    filesToInstall = [ "u-boot.bin" ];
  };
  armTrustedFirmwareBpiR3Sd = armTrustedFirmwareBpiR3 { uboot = ubootBpiR3Sd; bootDevice = "sdmmc"; };
  armTrustedFirmwareBpiR3Emmc = armTrustedFirmwareBpiR3 { uboot = ubootBpiR3Emmc; bootDevice = "emmc"; };
  bpiR3StuffCombined = pkgs.stdenvNoCC.mkDerivation {
    name = "bpi-r3-stuff";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/sd
      mkdir -p $out/emmc
      cp ${bpiR3StuffEmmc}/* $out/emmc
      cp ${bpiR3StuffSd}/* $out/sd
    '';
    fixupPhase = "true";
  };
  bpiR3StuffEmmc = pkgs.stdenvNoCC.mkDerivation {
    name = "bpi-r3-stuff-emmc";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out
      cp ${ubootBpiR3Emmc}/*.* $out
      cp ${armTrustedFirmwareBpiR3Emmc}/*.* $out
    '';
    fixupPhase = "true";
  };
  bpiR3StuffSd = pkgs.stdenvNoCC.mkDerivation {
    name = "bpi-r3-stuff-sd";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out
      cp ${ubootBpiR3Sd}/*.* $out
      cp ${armTrustedFirmwareBpiR3Sd}/*.* $out
    '';
    fixupPhase = "true";
  };
  linux_bpiR3 = pkgs.linux_testing.override {
    stdenv = pkgs'.ccacheStdenv;
    buildPackages = pkgs'.buildPackages // {
      stdenv = pkgs'.buildPackages.ccacheStdenv;
    };
    # there's probably more enabled-by-default configs that are better left disabled, but whatever
    structuredExtraConfig = with lib.kernel; {
      /* "Select this option if you are building a kernel for a server or
          scientific/computation system, or if you want to maximize the
          raw processing power of the kernel, irrespective of scheduling
          latencies." */
      PREEMPT_NONE = yes;
      # disable the other preempts
      PREEMPTION = no;
      PREEMPT_VOLUNTARY = lib.mkForce no;
      PREEMPT = no;

      CPU_FREQ_GOV_ONDEMAND = yes;
      CPU_FREQ_DEFAULT_GOV_ONDEMAND = yes;
      CPU_FREQ_DEFAULT_GOV_PERFORMANCE = lib.mkForce no;
      CPU_FREQ_GOV_CONSERVATIVE = yes;
      # disable virtualisation stuff
      PARAVIRT = lib.mkForce no;
      VIRTUALIZATION = no;
      XEN = lib.mkForce no;
      # zstd
      KERNEL_ZSTD = yes;
      MODULE_COMPRESS_ZSTD = yes;
      MODULE_DECOMPRESS = yes;
      FW_LOADER_COMPRESS_ZSTD = yes;
      # zram
      ZRAM_DEF_COMP_ZSTD = yes;
      CRYPTO_ZSTD = yes;
      ZRAM_MEMORY_TRACKING = yes;
      # router stuff
      IP_FIB_TRIE_STATS = yes;
      IP_ROUTE_CLASSID = yes;
      # adds sysctl net.ipv4.tcp_syncookies
      SYN_COOKIES = yes;
      WIREGUARD = yes;
      INET = yes;
      # stuff for ss
      NETLINK_DIAG = yes;
      # nftables features
      IP_SET = module;
      NF_CONNTRACK = module;
      NF_CONNTRACK_BRIDGE = module;
      NF_CONNTRACK_MARK = yes;
      NF_NAT = module;
      NF_FLOW_TABLE = module;
      NF_FLOW_TABLE_INET = module;
      NF_LOG_ARP = module;
      NF_LOG_IPV4 = module;
      NF_LOG_IPV6 = module;
      NETFILTER_NETLINK_QUEUE = module;
      NFT_BRIDGE_META = module;
      NFT_BRIDGE_REJECT = module;
      NFT_CONNLIMIT = module;
      NFT_CT = module;
      NFT_DUP_IPV4 = module;
      NFT_DUP_IPV6 = module;
      NFT_DUP_NETDEV = module;
      NFT_FIB = module;
      NFT_FIB_IPV4 = module;
      NFT_FIB_IPV6 = module;
      NFT_FIB_INET = module;
      NFT_FIB_NETDEV = module;
      NFT_FLOW_OFFLOAD = module;
      NFT_FWD_NETDEV = module;
      NFT_HASH = module;
      NFT_LIMIT = module;
      NFT_LOG = module;
      NFT_MASQ = module;
      NFT_NAT = module;
      NFT_NUMGEN = module;
      NFT_OSF = module;
      NFT_QUEUE = module;
      NFT_QUOTA = module;
      NFT_REDIR = module;
      NFT_REJECT = module;
      NFT_REJECT_IPV4 = module;
      NFT_REJECT_IPV6 = module;
      NFT_REJECT_INET = module;
      NFT_SOCKET = module;
      NFT_SYNPROXY = module;
      NFT_TPROXY = module;
      NFT_TUNNEL = module;

      BRIDGE = yes;
      HSR = no;
      NET_DSA = module;

      # packet CLaSsification
      NET_CLS_ROUTE4 = module;
      NET_CLS_FW = module;
      NET_CLS_U32 = module;
      NET_CLS_FLOW = module;
      NET_CLS_CGROUP = module;
      NET_CLS_FLOWER = module;
      NET_CLS_MATCHALL = module;
      NET_EMATCH = yes;
      NET_EMATCH_CMP = module;
      NET_EMATCH_NBYTE = module;
      NET_EMATCH_U32 = module;
      NET_EMATCH_META = module;
      NET_EMATCH_TEXT = module;
      NET_EMATCH_IPSET = module;

      # packet actions
      NET_CLS_ACT = yes;
      NET_ACT_POLICE = module;
      NET_ACT_GACT = module;
      NET_ACT_SAMPLE = module;
      NET_ACT_NAT = module;
      NET_ACT_PEDIT = module;
      NET_ACT_SKBEDIT = module;
      NET_ACT_CSUM = module;
      NET_ACT_MPLS = module;
      NET_ACT_VLAN = module;
      NET_ACT_CONNMARK = module;
      NET_ACT_CTINFO = module;
      NET_ACT_SKBMOD = module;
      NET_ACT_IFE = module;
      NET_ACT_TUNNEL_KEY = module;
      NET_ACT_CT = module;

      # random stuff
      PSAMPLE = module;
      RFKILL = yes;

      # hardware specific stuff
      FB = lib.mkForce no;
      DRM = no;

      NR_CPUS = lib.mkForce (freeform "4");
      SMP = yes;

      SFP = yes;
      ARCH_MEDIATEK = yes;
      MEDIATEK_WATCHDOG = yes;
      MTD_NAND_ECC_MEDIATEK = yes;
      MTD_NAND_ECC_SW_HAMMING = yes;
      MTD_NAND_MTK = yes;
      MTD_SPI_NAND = yes;
      MTD_UBI = yes;
      MTD_UBI_BLOCK = yes;
      NVMEM_MTK_EFUSE = yes;
      MTK_HSDMA = yes;
      MTK_INFRACFG = yes;
      MTK_PMIC_WRAP = yes;
      MTK_THERMAL = yes;
      MTK_TIMER = yes;
      NET_DSA_MT7530 = module;
      NET_MEDIATEK_SOC = module;
      NET_MEDIATEK_SOC_WED = yes;
      NET_MEDIATEK_STAR_EMAC = yes;
      NET_SWITCHDEV = yes;
      NET_VENDOR_MEDIATEK = yes;
      PCIE_MEDIATEK = yes;
      PCIE_MEDIATEK_GEN3 = yes;
      PINCTRL_MT7986 = yes;
      PWM_MEDIATEK = yes;
      MT7915E = module;
      MT7986_WMAC = yes;
      SPI_MT65XX = yes;
      SPI_MTK_NOR = yes;
      SPI_MTK_SNFI = yes;
      MMC_MTK = yes;
    };
  };
  linuxPackages_bpiR3 = pkgs.linuxPackagesFor linux_bpiR3;
  ccacheWrapper = pkgs.ccacheWrapper.override {
    extraConfig = ''
      export CCACHE_COMPRESS=1
      export CCACHE_DIR="/var/cache/ccache"
      export CCACHE_UMASK=007
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
  };

  firefox-addons = lib.recurseIntoAttrs (callPackage ./firefox-addons { inherit nur sources; });
  mpvScripts = pkgs.mpvScripts // (callPackage ./mpv-scripts { });
}
