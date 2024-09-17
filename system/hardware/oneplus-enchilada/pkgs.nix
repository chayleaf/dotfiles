{ pkgs
, pkgs'
, lib
, inputs
, ... }:

let
  inherit (inputs) mobile-nixos;
  mobile-pkgs = import "${mobile-nixos}/overlay/overlay.nix" pkgs' pkgs;
in {
  inherit (mobile-pkgs) mkbootimg qrtr;
  pd-mapper = pkgs'.callPackage "${mobile-nixos}/overlay/qrtr/pd-mapper.nix" { };
  tqftpserv = pkgs'.callPackage "${mobile-nixos}/overlay/qrtr/tqftpserv.nix" { };
  rmtfs = pkgs'.callPackage "${mobile-nixos}/overlay/qrtr/rmtfs.nix" {
    inherit (mobile-pkgs) qmic;
  };
  adbd = pkgs'.callPackage "${mobile-nixos}/overlay/adbd" {
    libhybris = pkgs'.callPackage "${mobile-nixos}/overlay/libhybris" {
      inherit (mobile-pkgs) android-headers;
    };
  };
  q6voiced = pkgs.stdenv.mkDerivation {
    pname = "q6voiced";
    version = "unstable-2022-07-08";
    src = pkgs.fetchFromGitLab {
      owner = "postmarketOS";
      repo = "q6voiced";
      rev = "736138bfc9f7b455a96679e2d67fd922a8f16464";
      hash = "sha256-7k5saedIALHlsFHalStqzKrqAyFKx0ZN9FhLTdxAmf4=";
    };
    buildInputs = with pkgs; [ dbus tinyalsa ];
    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildPhase = ''cc $(pkg-config --cflags --libs dbus-1) -ltinyalsa -o q6voiced q6voiced.c'';
    installPhase = ''install -m555 -Dt "$out/bin" q6voiced'';
    meta.license = lib.licenses.mit;
  };

  alsa-ucm-conf = pkgs.stdenvNoCC.mkDerivation {
    pname = "alsa-ucm-conf-enchilada";
    version = "unstable-2022-12-08";
    src = pkgs.fetchFromGitLab {
      owner = "sdm845-mainline";
      repo = "alsa-ucm-conf";
      rev = "aaa7889f7a6de640b4d78300e118457335ad16c0";
      hash = "sha256-2P5ZTrI1vCJ99BcZVPlkH4sv1M6IfAlaXR6ZjAdy4HQ=";
    };
    installPhase = ''
      substituteInPlace ucm2/lib/card-init.conf --replace '"/bin' '"/run/current-system/sw/bin'
      mkdir -p "$out"/share/alsa/ucm2/{OnePlus,conf.d/sdm845,lib}
      mv ucm2/lib/card-init.conf "$out/share/alsa/ucm2/lib/"
      mv ucm2/OnePlus/enchilada "$out/share/alsa/ucm2/OnePlus/"
      ln -s ../../OnePlus/enchilada/enchilada.conf "$out/share/alsa/ucm2/conf.d/sdm845/oneplus-OnePlus6-Unknown.conf"
    '';
    # to overwrite card-init.conf
    meta.priority = -10;
  };

  uboot = pkgs.buildUBoot {
    defconfig = "qcom_defconfig";
    version = "unstable-2023-12-11";
    src = pkgs.fetchFromGitLab {
      owner = "sdm845-mainline";
      repo = "u-boot";
      rev = "977b9279c610b862f9ef84fb3addbebb7c42166a";
      hash = "sha256-ksI7qxozIjJ5E8uAJkX8ZuaaOHdv76XOzITaA8Vp/QA=";
    };
    makeFlags = [ "DEVICE_TREE=sdm845-oneplus-enchilada" ];
    extraConfig = ''
      CONFIG_BOOTDELAY=5
    '';
    extraMeta.platforms = [ "aarch64-linux" ];
    patches = [ ];
    filesToInstall = [ "u-boot-nodtb.bin" "u-boot-dtb.bin" "u-boot.dtb" ];
  };

  ubootImage = pkgs.stdenvNoCC.mkDerivation {
    name = "u-boot-enchilada.img";
    nativeBuildInputs = [
      # available from mobile-nixos's overlay
      pkgs'.mkbootimg
      pkgs'.gzip
    ];
    src = pkgs'.ubootEnchilada;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      gzip u-boot-nodtb.bin
      cat u-boot.dtb >> u-boot-nodtb.bin.gz
      mkbootimg \
        --base 0x0 \
        --kernel_offset 0x8000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x100 \
        --pagesize 4096 \
        --kernel u-boot-nodtb.bin.gz \
        -o "$out"
    '';
  };

  firmware = pkgs.stdenvNoCC.mkDerivation {
    name = "firmware-oneplus-sdm845";
    src = pkgs.fetchFromGitLab {
      owner = "sdm845-mainline";
      repo = "firmware-oneplus-sdm845";
      rev = "176ca713448c5237a983fb1f158cf3a5c251d775";
      hash = "sha256-ZrBvYO+MY0tlamJngdwhCsI1qpA/2FXoyEys5FAYLj4=";
    };
    installPhase = ''
      cp -a . "$out"
      cd "$out/lib/firmware/postmarketos"
      find . -type f,l | xargs -i bash -c 'mkdir -p "$(dirname "../$1")" && mv "$1" "../$1"' -- {}
      cd "$out/usr"
      find . -type f,l | xargs -i bash -c 'mkdir -p "$(dirname "../$1")" && mv "$1" "../$1"' -- {}
      cd ..
      find "$out/lib/firmware/postmarketos" "$out/usr" | tac | xargs rmdir
    '';
    dontStrip = true;
    # not actually redistributable, but who cares
    meta.license = lib.licenses.unfreeRedistributableFirmware;
  };

  linux = pkgs.linux_testing.override {
    # TODO: uncomment
    # ignoreConfigErrors = false;
    kernelPatches = [
      {
        name = "linux_6_11";
        patch = pkgs.fetchpatch {
          url = "https://github.com/chayleaf/linux-sdm845/compare/v6.11-rc2...7223c2b9c8917c0e315ee7ec53cee27cc1054b16.diff";
          hash = "sha256-BxRBmB89wxXXD09FP6dZi1bsn7/fCihQRbnAUOJwEvc=";
        };
      }
      # {
      #   name = "linux_6_9";
      #   patch = pkgs.fetchpatch {
      #     url = "https://github.com/chayleaf/linux-sdm845/compare/v6.9.12...1ffe541f384cdfee347bf92773a740677de1b824.diff";
      #     hash = "sha256-6TMiXaZy8YEB2vmrpXwAKklHYhvlA/TklCQv95iyMNY=";
      #   };
      # }
      {
        name = "config_fixes";
        # patch = ./config_fixes.patch;
        patch = ./config_fixes_611.patch;
      }
    ];

    stdenv = lib.recursiveUpdate pkgs.stdenv {
      hostPlatform.linux-kernel.extraConfig = "";
    };

    structuredExtraConfig = with lib.kernel; {
      # fix build
      LENOVO_YOGA_C630_EC = no;
      RPMSG_QCOM_GLINK_SMEM = yes;
      TOUCHSCREEN_STM_FTS_DOWNSTREAM = no;
      TOUCHSCREEN_FTM4 = no;
      # for adb and stuff (doesn't have to be built-in, but it's easier that way)
      USB_FUNCTIONFS = yes;
      USB_LIBCOMPOSITE = yes;
      USB_F_ACM = yes;
      USB_U_SERIAL = yes;
      USB_U_ETHER = yes;
      USB_F_SERIAL = yes;
      USB_F_OBEX = yes;
      USB_F_NCM = yes;
      USB_F_ECM = yes;
      USB_F_EEM = yes;
      USB_F_SUBSET = yes;
      USB_F_RNDIS = yes;
      USB_F_MASS_STORAGE = yes;
      USB_F_FS = yes;
      USB_F_HID = yes;
      USB_CONFIGFS = yes;
      USB_CONFIGFS_F_HID = yes;
      REGULATOR_QCOM_USB_VBUS = module;
      LEDS_TRIGGER_ONESHOT = yes;
      LEDS_TRIGGER_BACKLIGHT = yes;
      LEDS_TRIGGER_ACTIVITY = yes;

      # adapted from https://gitlab.com/sdm845-mainline/linux/-/blob/3e9f7c18a3f681b52b7ea87765be267cd1e8b870/arch/arm64/configs/sdm845.config
      # enchilada-specific
      DRM_PANEL_SAMSUNG_SOFEF00 = yes;
      BATTERY_BQ27XXX = module;
      HID_RMI = module;
      RMI4_CORE = module;
      RMI4_I2C = module;
      RMI4_F55 = yes;
      # common sdm845
      HIBERNATION = lib.mkForce no;
      QCOM_RPROC_COMMON = yes;
      FORCE_NR_CPUS = yes;
      NR_CPUS = lib.mkForce (freeform "8");
      SCSI_UFS_QCOM = yes;
      QCOM_GSBI = yes;
      QCOM_LLCC = yes;
      QCOM_OCMEM = yes;
      QCOM_RMTFS_MEM = yes;
      QCOM_SOCINFO = yes;
      QCOM_WCNSS_CTRL = yes;
      QCOM_APR = yes;
      POWER_RESET_QCOM_PON = yes;
      QCOM_SPMI_TEMP_ALARM = yes;
      QCOM_LMH = yes;
      SCHED_CLUSTER = yes;
      SND_SOC_QDSP6_Q6VOICE = module;
      SCSI_UFS_BSG = yes;
      PHY_QCOM_QMP_PCIE = yes;
      BACKLIGHT_CLASS_DEVICE = yes;
      INTERCONNECT_QCOM_OSM_L3 = yes;
      LEDS_TRIGGER_PATTERN = yes;
      LEDS_CLASS_MULTICOLOR = module;
      LEDS_QCOM_LPG = module;
      I2C_QCOM_GENI = yes;
      LEDS_QCOM_FLASH = module;
      SLIMBUS = yes;
      SLIM_QCOM_CTRL = yes;
      SLIM_QCOM_NGD_CTRL = yes;
      REMOTEPROC_CDEV = yes;
      BATTERY_QCOM_FG = module;
      CHARGER_QCOM_SMB2 = module;
      QCOM_SPMI_RRADC = module;
      DRM = yes;
      DRM_MSM = yes;
      VIDEO_VIVID = module;
      REGULATOR_QCOM_LABIBB = yes;
      BACKLIGHT_QCOM_WLED = yes;
      INPUT_QCOM_SPMI_HAPTICS = module;
      PM_AUTOSLEEP = yes;
      SCSI_SCAN_ASYNC = yes;
      DMABUF_HEAPS = yes;
      UDMABUF = yes;
      DMABUF_HEAPS_CMA = yes;
      DMABUF_HEAPS_SYSTEM = yes;
      HZ_1000 = yes;
      UCLAMP_TASK = yes;
      UCLAMP_TASK_GROUP = yes;
      RPMSG_CHAR = yes;
      QCOM_Q6V5_ADSP = module;
      BT_RFCOMM = module;
      BT_RFCOMM_TTY = yes;
      BT_BNEP = module;
      BT_BNEP_MC_FILTER = yes;
      BT_BNEP_PROTO_FILTER = yes;
      BT_HS = yes;
      BT_LE = yes;
      QCOM_COINCELL = module;
      QCOM_FASTRPC = module;
      QCOM_SPMI_VADC = yes;
      QCOM_SPMI_ADC5 = yes;
      PHY_QCOM_QMP = yes;
      PHY_QCOM_QUSB2 = yes;
      PHY_QCOM_QMP_UFS = yes;
      TYPEC = yes;
      PHY_QCOM_QMP_COMBO = yes;
      LEDS_CLASS_FLASH = yes;
      TCP_CONG_WESTWOOD = yes;
      DEFAULT_WESTWOOD = yes;
      BLK_DEV_RAM = yes;
      BLK_DEV_RAM_SIZE = freeform "8192";
      CPU_FREQ_GOV_POWERSAVE = yes;
      SYN_COOKIES = yes;
      INPUT_UINPUT = module;
      U_SERIAL_CONSOLE = yes;
      USB_ANNOUNCE_NEW_DEVICES = yes;
      BLK_INLINE_ENCRYPTION = yes;
      PHY_QCOM_SNPS_EUSB2 = module;
      MFD_QCOM_RPM = yes;
      USB_DWC3_ULPI = yes;
      SCSI_UFS_CRYPTO = yes;
      PHY_QCOM_USB_HS = yes;
      PHY_QCOM_USB_SNPS_FEMTO_V2 = yes;
      INTERCONNECT_QCOM_SM6115 = yes;
      SM_DISPCC_6115 = yes;
      FS_ENCRYPTION_INLINE_CRYPT = yes;
      CRYPTO_USER_API_AEAD = yes;
      CRYPTO_DEV_QCE = yes;
      DMA_CMA = yes;
      SM_GPUCC_6115 = yes;
      USB_ONBOARD_HUB = no; # breaks USB on qualcomm rb2... which i don't need, but i guess this won't hurt either way
      INTERCONNECT_QCOM_QCM2290 = yes;
      BRIDGE_NETFILTER = module;
      NEW_LEDS = yes;
      LEDS_CLASS = yes;
      CMA = yes;
      CMA_SIZE_MBYTES = lib.mkForce (freeform "256");
      # CONFIG END (essentially)

      # the rest of the config is just disabling unneeded stuff, feel free to ignore this
      ARCH_SPARX5 = no;
      ARCH_MA35 = no;
      ARCH_REALTEK = no;
      ARCH_STM32 = no;
      BLK_DEV_NVME = no;
      ATA = no;
      MTD = no;
      SRAM = no;
      MEGARAID_SAS = no;
      EEPROM_AT25 = no;
      USB_DWC2 = no;
      USB_CHIPIDEA = no;
      USB_MUSB_HDRC = no;
      USB_ISP1760 = no;
      USB_HSIC_USB3503 = no;
      USB_NET_PLUSB = no;
      TYPEC_FUSB302 = no;
      EXTCON_PTN5150 = no;
      NET_VENDOR_NI = no;
      NET_9P = no;
      CAN = no;
      BNX2X = no;
      MACB = no;
      IGB = no;
      IGBVF = no;
      SMC91X = no;
      MLX4_EN = no;
      MLX5_CORE = no;
      STMMAC_ETH = no;
      ATL1C = no;
      BRCMFMAC = no;
      WL18XX = no;
      ATH10K_PCI = no;
      NET_SCH_CBS = no;
      NET_SCH_ETF = no;
      NET_SCH_TAPRIO = no;
      NET_SCH_MQPRIO = no;
      NET_CLS_BASIC = no;
      NET_CLS_FLOWER = no;
      NET_CLS_ACT = no;
      MDIO_BUS_MUX_MMIOREG = no;
      MDIO_BUS_MUX_MULTIPLEXER = no;
      SND_SOC_ES7134 = no;
      SND_SOC_ES7241 = no;
      SND_SOC_TAS571X = no;
      SND_SOC_SIMPLE_AMPLIFIER = no;
      GPIO_DWAPB = no;
      COMMON_CLK_XGENE = no;
      SENSORS_ARM_SCPI = no;
      TCG_TPM = no;
      BATTERY_SBS = no;
      REGULATOR_VCTRL = no;
      CAVIUM_ERRATUM_22375 = no;
      CAVIUM_ERRATUM_23154 = no;
      CAVIUM_ERRATUM_27456 = no;
      CAVIUM_ERRATUM_30115 = no;
      CAVIUM_TX2_ERRATUM_219 = no;
      EEPROM_AT24 = no;
      NET_DSA = no;
      AQUANTIA_PHY = no;
      MICROSEMI_PHY = no;
      VITESSE_PHY = no;
      I2C_MUX_PCA954x = no;
      SND_SOC_PCM3168A_I2C = no;
      SENSORS_LM90 = no;
      SENSORS_INA2XX = no;
      RTC_DRV_DS3232 = no;
      GPIO_MAX732X = no;
      SENSORS_ISL29018 = no;
      MPL3115 = no;
      MFD_ROHM_BD718XX = no;
      ARM_SBSA_WATCHDOG = no;
      ARM_SMC_WATCHDOG = no;
      REGULATOR_PCA9450 = no;
      REGULATOR_PFUZE100 = no;
      DRM_PANEL_ABT_Y030XX067A = no;
      DRM_PANEL_ARM_VERSATILE = no;
      DRM_PANEL_ASUS_Z00T_TM5P5_NT35596 = no;
      DRM_PANEL_AUO_A030JTN01 = no;
      DRM_PANEL_BOE_BF060Y8M_AJ0 = no;
      DRM_PANEL_BOE_HIMAX8279D = no;
      DRM_PANEL_ELIDA_KD35T133 = no;
      DRM_PANEL_FEIXIN_K101_IM2BA02 = no;
      DRM_PANEL_FEIYANG_FY07024DI26A30D = no;
      DRM_PANEL_HIMAX_HX8394 = no;
      DRM_PANEL_ILITEK_IL9322 = no;
      DRM_PANEL_ILITEK_ILI9341 = no;
      DRM_PANEL_ILITEK_ILI9881C = no;
      DRM_PANEL_ILITEK_ILI9882T = no;
      DRM_PANEL_INNOLUX_EJ030NA = no;
      DRM_PANEL_INNOLUX_P079ZCA = no;
      DRM_PANEL_JADARD_JD9365DA_H3 = no;
      DRM_PANEL_JDI_LPM102A188A = no;
      DRM_PANEL_JDI_LT070ME05000 = no;
      DRM_PANEL_JDI_R63452 = no;
      DRM_PANEL_KHADAS_TS050 = no;
      DRM_PANEL_KINGDISPLAY_KD097D04 = no;
      DRM_PANEL_LEADTEK_LTK050H3146W = no;
      DRM_PANEL_LEADTEK_LTK500HD1829 = no;
      DRM_PANEL_LG_LB035Q02 = no;
      DRM_PANEL_LG_LG4573 = no;
      DRM_PANEL_MAGNACHIP_D53E6EA8966 = no;
      DRM_PANEL_NEC_NL8048HL11 = no;
      DRM_PANEL_NEWVISION_NV3051D = no;
      DRM_PANEL_NEWVISION_NV3052C = no;
      DRM_PANEL_NOVATEK_NT35510 = no;
      DRM_PANEL_NOVATEK_NT35560 = no;
      DRM_PANEL_NOVATEK_NT35950 = no;
      DRM_PANEL_NOVATEK_NT36523 = no;
      DRM_PANEL_NOVATEK_NT39016 = no;
      DRM_PANEL_OLIMEX_LCD_OLINUXINO = no;
      DRM_PANEL_ORISETECH_OTA5601A = no;
      DRM_PANEL_ORISETECH_OTM8009A = no;
      DRM_PANEL_OSD_OSD101T2587_53TS = no;
      DRM_PANEL_PANASONIC_VVX10F034N00 = no;
      DRM_PANEL_RASPBERRYPI_TOUCHSCREEN = no;
      DRM_PANEL_RAYDIUM_RM67191 = no;
      DRM_PANEL_RAYDIUM_RM68200 = no;
      DRM_PANEL_RAYDIUM_RM692E5 = no;
      DRM_PANEL_RONBO_RB070D30 = no;
      DRM_PANEL_SAMSUNG_ATNA33XC20 = no;
      DRM_PANEL_SAMSUNG_DB7430 = no;
      DRM_PANEL_SAMSUNG_LD9040 = no;
      DRM_PANEL_SAMSUNG_S6D16D0 = no;
      DRM_PANEL_SAMSUNG_S6D27A1 = no;
      DRM_PANEL_SAMSUNG_S6D7AA0 = no;
      DRM_PANEL_SAMSUNG_S6E3HA2 = no;
      DRM_PANEL_SAMSUNG_S6E63J0X03 = no;
      DRM_PANEL_SAMSUNG_S6E63M0 = no;
      DRM_PANEL_SAMSUNG_S6E88A0_AMS452EF01 = no;
      DRM_PANEL_SAMSUNG_S6E8AA0 = no;
      DRM_PANEL_SEIKO_43WVF1G = no;
      DRM_PANEL_SHARP_LQ101R1SX01 = no;
      DRM_PANEL_SHARP_LS037V7DW01 = no;
      DRM_PANEL_SHARP_LS043T1LE01 = no;
      DRM_PANEL_SHARP_LS060T1SX01 = no;
      DRM_PANEL_SITRONIX_ST7701 = no;
      DRM_PANEL_SITRONIX_ST7703 = no;
      DRM_PANEL_SITRONIX_ST7789V = no;
      DRM_PANEL_SONY_ACX565AKM = no;
      DRM_PANEL_SONY_TD4353_JDI = no;
      DRM_PANEL_SONY_TULIP_TRULY_NT35521 = no;
      DRM_PANEL_STARTEK_KD070FHFID015 = no;
      DRM_PANEL_TDO_TL070WSH30 = no;
      DRM_PANEL_TPO_TD028TTEC1 = no;
      DRM_PANEL_TPO_TD043MTEA1 = no;
      DRM_PANEL_TPO_TPG110 = no;
      DRM_PANEL_VISIONOX_R66451 = no;
      DRM_PANEL_VISIONOX_RM69299 = no;
      DRM_PANEL_WIDECHIPS_WS2401 = no;
      DRM_PANEL_XINPENG_XPP055C272 = no;
      DRM_NWL_MIPI_DSI = no;
      SND_SOC_FSL_SAI = no;
      SND_SOC_FSL_ASRC = no;
      SND_SOC_FSL_MICFIL = no;
      SND_SOC_FSL_AUDMIX = no;
      SND_SOC_FSL_SPDIF = no;
      SND_SOC_WM8904 = no;
      RTC_DRV_RV8803 = no;
      RTC_DRV_DS1307 = no;
      RTC_DRV_PCF85363 = no;
      RTC_DRV_PCF2127 = no;
      FUJITSU_ERRATUM_010001 = no;
      PCI_PASID = no;
      UACCE = no;
      SPI_CADENCE_QUADSPI = no;
      DW_WATCHDOG = no;
      NOP_USB_XCEIV = no;
      SURFACE_PLATFORMS = no;
      GPIO_PCA953X = no;
      BACKLIGHT_LP855X = no;
      MFD_MAX77620 = no;
      SENSORS_PWM_FAN = no;
      SENSORS_INA3221 = no;
      REGULATOR_MAX8973 = no;
      USB_CONN_GPIO = no;
      MFD_BD9571MWV = no;
      DRM_PANEL_LVDS = no;
      COMMON_CLK_VC5 = no;
      CRYPTO_DEV_CCREE = no;
      VIDEO_IMX219 = no;
      VIDEO_OV5645 = no;
      SND_SOC_AK4613 = no;
      SND_SIMPLE_CARD = no;
      SND_AUDIO_GRAPH_CARD = no;
      TYPEC_HD3SS3220 = no;
      RTC_DRV_RX8581 = no;
      COMMON_CLK_CS2000_CP = no;
      KEYBOARD_ADC = no;
      REGULATOR_FAN53555 = no;
      TOUCHSCREEN_ATMEL_MXT = no;
      RTC_DRV_HYM8563 = no;
      MFD_SEC_CORE = no;
      PL330_DMA = no;
      GPIO_MB86S7X = no;
      MMC_SDHCI_F_SDH30 = no;
      MMC_SDHCI_CADENCE = no;
      SOCIONEXT_SYNQUACER_PREITS = no;
      NET_VENDOR_SOCIONEXT = no;
      ARCH_ACTIONS = no;
      ARCH_SUNXI = no;
      ARCH_ALPINE = no;
      ARCH_APPLE = no;
      ARCH_BERLIN = no;
      ARCH_EXYNOS = no;
      ARCH_K3 = no;
      ARCH_LG1K = no;
      ARCH_HISI = no;
      ARCH_KEEMBAY = no;
      ARCH_MEDIATEK = no;
      ARCH_MESON = no;
      ARCH_MVEBU = no;
      ARCH_RENESAS = no;
      ARCH_ROCKCHIP = no;
      ARCH_SEATTLE = no;
      ARCH_INTEL_SOCFPGA = no;
      ARCH_SYNQUACER = no;
      ARCH_TEGRA = no;
      ARCH_SPRD = no;
      ARCH_THUNDER = no;
      ARCH_THUNDER2 = no;
      ARCH_UNIPHIER = no;
      ARCH_VEXPRESS = no;
      ARCH_VISCONTI = no;
      ARCH_XGENE = no;
      ARCH_ZYNQMP = no;
      PCI_XGENE = no;
      PCIE_ALTERA = no;
      PCI_HOST_THUNDER_PEM = no;
      PCI_HOST_THUNDER_ECAM = no;
      PCI_HISI = no;
      PCIE_KIRIN = no;
      SERIAL_XILINX_PS_UART = no;
      SERIAL_FSL_LPUART = no;
      SERIAL_FSL_LINFLEXUART = no;
      I2C_RK3X = no;
      SPI_PL022 = no;
      GPIO_ALTERA = no;
      GPIO_PL061 = no;
      GPIO_XGENE = no;
      POWER_RESET_XGENE = no;
      POWER_RESET_SYSCON = no;
      GNSS_MTK_SERIAL = no;
      ARM_SP805_WATCHDOG = no;
      MFD_AXP20X_I2C = no;
      MFD_HI6421_PMIC = no;
      MFD_MT6397 = no;
      REGULATOR_RK808 = no;
      REGULATOR_TPS65132 = no;
      MEDIA_ANALOG_TV_SUPPORT = lib.mkForce no;
      MEDIA_DIGITAL_TV_SUPPORT = lib.mkForce no;
      MEDIA_SDR_SUPPORT = no;
      DRM_AMDGPU = no;
      DRM_ETNAVIV = no;
      DRM_HISI_KIRIN = no;
      DRM_NOUVEAU = no;
      SND_SOC_GTM601 = no;
      SND_SOC_RT5659 = no;
      SND_SOC_WM8960 = no;
      SND_SOC_WM8962 = no;
      USB_XHCI_PCI_RENESAS = no;
      MMC_SDHCI_OF_ARASAN = no;
      MMC_DW_EXYNOS = no;
      MMC_DW_HI3798CV200 = no;
      MMC_DW_K3 = no;
      MMC_MTK = no;
      MMC_SDHCI_XENON = no;
      MMC_SDHCI_AM654 = no;
      RTC_DRV_MAX77686 = no;
      RTC_DRV_RK808 = no;
      RTC_DRV_M41T80 = no;
      RTC_DRV_RV3028 = no;
      RTC_DRV_PL031 = no;
      COMMON_CLK_RK808 = no;
      FSL_RCPM = no;
      HISI_PMU = no;
      INTERCONNECT_QCOM_MSM8996 = no;
      INTERCONNECT_QCOM_QCS404 = no;
      ARCH_NPCM = no;
      PINCTRL_SC8280XP = no;
      BCM_SBA_RAID = no;
      SENSORS_GPIO_FAN = no;
      ARCH_BCM = no;
      ARCH_NXP = no;
      NET_VENDOR_ADI = no;
      PINCTRL_SC8180X = no;
      SND_SOC_SC7180 = no;
      SND_SOC_SC7280 = no;
      SND_SOC_WCD938X_SDW = no;
      MMC_SDHCI_OF_DWCMSHC = no;
      IOMMU_IO_PGTABLE_DART = no;
      MEMORY_HOTPLUG = lib.mkForce no;
      MELLANOX_PLATFORM = no;
      SM_VIDEOCC_8150 = no;
      SM_GPUCC_8350 = no;
      SM_VIDEOCC_8350 = no;

      # keys that are unused in this case
      # (builtin aarch64-linux config is unused too, but i cant disable it)
      ACPI_HOTPLUG_MEMORY.tristate = lib.mkForce null; BCM2835_MBOX.tristate = lib.mkForce null; BCM2835_WDT.tristate = lib.mkForce null;
      CHROMEOS_TBMC.tristate = lib.mkForce null; CROS_EC.tristate = lib.mkForce null; CROS_EC_I2C.tristate = lib.mkForce null;
      CROS_EC_SPI.tristate = lib.mkForce null; CROS_KBD_LED_BACKLIGHT.tristate = lib.mkForce null;
      FSL_MC_UAPI_SUPPORT.tristate = lib.mkForce null; MEDIA_ATTACH.tristate = lib.mkForce null;
      MEMORY_HOTREMOVE.tristate = lib.mkForce null; MTD_COMPLEX_MAPPINGS.tristate = lib.mkForce null; NET_ACT_BPF.tristate = lib.mkForce null;
      PCI_TEGRA.tristate = lib.mkForce null; RASPBERRYPI_FIRMWARE.tristate = lib.mkForce null; RASPBERRYPI_POWER.tristate = lib.mkForce null;
      SCSI_SAS_ATA.tristate = lib.mkForce null; SUN8I_DE2_CCU.tristate = lib.mkForce null;
      TCG_TIS_SPI_CR50.tristate = lib.mkForce null; USB_XHCI_TEGRA = lib.mkForce no; ZONE_DEVICE.tristate = lib.mkForce null;
      "9P_FSCACHE".tristate = lib.mkForce null; CROS_EC_ISHTP.tristate = lib.mkForce null; CROS_EC_LPC.tristate = lib.mkForce null;
      DRM_AMDGPU_CIK.tristate = lib.mkForce null; DRM_AMDGPU_SI.tristate = lib.mkForce null; DRM_AMDGPU_USERPTR.tristate = lib.mkForce null;
      DRM_AMD_DC_FP.tristate = lib.mkForce null; DRM_AMD_DC_SI.tristate = lib.mkForce null; DRM_DP_AUX_CHARDEV.tristate = lib.mkForce null;
      DRM_FBDEV_EMULATION.tristate = lib.mkForce null; DRM_GMA500.tristate = lib.mkForce null; DRM_LEGACY.tristate = lib.mkForce null;
      DRM_LOAD_EDID_FIRMWARE.tristate = lib.mkForce null; DRM_VBOXVIDEO.tristate = lib.mkForce null;
      DRM_VC4_HDMI_CEC.tristate = lib.mkForce null; FB_3DFX_ACCEL.tristate = lib.mkForce null; FB_ATY_CT.tristate = lib.mkForce null;
      FB_ATY_GX.tristate = lib.mkForce null; FB_EFI.tristate = lib.mkForce null; FB_NVIDIA_I2C.tristate = lib.mkForce null;
      FB_RIVA_I2C.tristate = lib.mkForce null; FB_SAVAGE_ACCEL.tristate = lib.mkForce null; FB_SAVAGE_I2C.tristate = lib.mkForce null;
      FB_SIS_300.tristate = lib.mkForce null; FB_SIS_315.tristate = lib.mkForce null;
      FB_VESA.tristate = lib.mkForce null; FONTS.tristate = lib.mkForce null; FONT_8x8.tristate = lib.mkForce null;
      FONT_TER16x32.tristate = lib.mkForce null; FRAMEBUFFER_CONSOLE.tristate = lib.mkForce null;
      FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER.tristate = lib.mkForce null;
      FRAMEBUFFER_CONSOLE_DETECT_PRIMARY.tristate = lib.mkForce null; FRAMEBUFFER_CONSOLE_ROTATION.tristate = lib.mkForce null;
      HMM_MIRROR.tristate = lib.mkForce null; HSA_AMD.tristate = lib.mkForce null; HYPERVISOR_GUEST.tristate = lib.mkForce null;
      INFINIBAND_IPOIB.tristate = lib.mkForce null; INFINIBAND_IPOIB_CM.tristate = lib.mkForce null;
      IP_MROUTE_MULTIPLE_TABLES.tristate = lib.mkForce null; JOYSTICK_PSXPAD_SPI_FF.tristate = lib.mkForce null;
      KERNEL_ZSTD.tristate = lib.mkForce null; KEYBOARD_APPLESPI.tristate = lib.mkForce null; KVM_ASYNC_PF.tristate = lib.mkForce null;
      KVM_GENERIC_DIRTYLOG_READ_PROTECT.tristate = lib.mkForce null; KVM_GUEST.tristate = lib.mkForce null; KVM_MMIO.tristate = lib.mkForce null;
      KVM_VFIO.tristate = lib.mkForce null; LOGO.tristate = lib.mkForce null; MICROCODE.tristate = lib.mkForce null;
      MOUSE_PS2_VMMOUSE.tristate = lib.mkForce null; MTRR_SANITIZER.tristate = lib.mkForce null; NFS_FSCACHE.tristate = lib.mkForce null;
      PINCTRL_BAYTRAIL.tristate = lib.mkForce null;
      PINCTRL_CHERRYVIEW.tristate = lib.mkForce null; PM_ADVANCED_DEBUG.tristate = lib.mkForce null; PM_TRACE_RTC.tristate = lib.mkForce null;
      SND_AC97_POWER_SAVE.tristate = lib.mkForce null; SND_DYNAMIC_MINORS.tristate = lib.mkForce null;
      SND_HDA_INPUT_BEEP.tristate = lib.mkForce null; SND_HDA_PATCH_LOADER.tristate = lib.mkForce null;
      SND_HDA_RECONFIG.tristate = lib.mkForce null; SND_OSSEMUL.tristate = lib.mkForce null; SND_USB_CAIAQ_INPUT.tristate = lib.mkForce null;
      VFIO_PCI_VGA.tristate = lib.mkForce null; VGA_SWITCHEROO.tristate = lib.mkForce null; X86_AMD_PLATFORM_DEVICE.tristate = lib.mkForce null;
      X86_CHECK_BIOS_CORRUPTION.tristate = lib.mkForce null; X86_MCE.tristate = lib.mkForce null;
      X86_PLATFORM_DRIVERS_DELL.tristate = lib.mkForce null; X86_PLATFORM_DRIVERS_HP.tristate = lib.mkForce null;
      JOYSTICK_XPAD_FF.tristate = lib.mkForce null; JOYSTICK_XPAD_LEDS.tristate = lib.mkForce null; KEXEC_JUMP.tristate = lib.mkForce null;
      PERF_EVENTS_AMD_BRS.tristate = lib.mkForce null; HVC_XEN.tristate = lib.mkForce null; HVC_XEN_FRONTEND.tristate = lib.mkForce null;
      PARAVIRT_SPINLOCKS.tristate = lib.mkForce null; PCI_XEN.tristate = lib.mkForce null; SWIOTLB_XEN.tristate = lib.mkForce null;
      VBOXGUEST.tristate = lib.mkForce null; XEN_BACKEND.tristate = lib.mkForce null; XEN_BALLOON.tristate = lib.mkForce null;
      XEN_BALLOON_MEMORY_HOTPLUG.tristate = lib.mkForce null; XEN_DOM0.tristate = lib.mkForce null; XEN_EFI.tristate = lib.mkForce null;
      XEN_HAVE_PVMMU.tristate = lib.mkForce null; XEN_MCE_LOG.tristate = lib.mkForce null; XEN_PVH.tristate = lib.mkForce null;
      XEN_PVHVM.tristate = lib.mkForce null; XEN_SAVE_RESTORE.tristate = lib.mkForce null; XEN_SYS_HYPERVISOR.tristate = lib.mkForce null;
    };
  };
  linux_ccache = pkgs'.ccachePkgs.buildLinuxWithCcache pkgs'.hw.oneplus-enchilada.linux;
}
