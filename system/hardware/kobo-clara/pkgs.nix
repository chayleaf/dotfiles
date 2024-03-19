{ pkgs
, lib
, ...
}:

{
  ubootKoboClara = pkgs.buildUBoot {
    defconfig = "mx6sllclarahd_defconfig";
    extraConfig = ''
      CONFIG_CMD_BOOTEFI=y
      CONFIG_EFI_LOADER=y
    ''; /*
      CONFIG_BOOTCOMMAND="${builtins.replaceStrings [ "\n" ] [ "; " ] ''
      detect_clara_rev
      load_ntxkernel
      echo Loading kernel
      load mmc 0:1 0x80800000 vmlinuz
      echo Loading DTB
      load mmc 0:1 0x83000000 imx6sll-kobo-clarahd.dtb
      echo Loading initrd
      load mmc 0:1 0x85000000 uInitrd
      echo Booting kernel
      bootz 0x80800000 0x85000000 0x83000000
      ''};"
    '';*/
    src = pkgs.fetchFromGitHub {
      owner = "akemnade";
      repo = "u-boot-fslc";
      hash = lib.fakeHash;
      rev = "a3816f6b51b5dc9083af4142ca5f3a4e4a235336";
    };
    version = "2016.03";
    extraMeta.platforms = [ "armv7l-linux" ];
    patches = [ ./mt7986-default-bootcmd.patch ];
    filesToInstall = [ "u-boot.bin" "u-boot.imx" ];
  };
  firmware-kobo-clara = pkgs.stdenv.mkDerivation rec {
    pname = "firmware-kobo-clara";
    version = "4.26.16704";
    src = pkgs.fetchzip {
      url = "https://download.kobobooks.com/firmwares/kobo7/Feb2021/kobo-update-${version}.zip";
      hash = lib.fakeHash;
    };
    hwcfg = pkgs.fetchurl {
      url = "https://gitlab.com/postmarketOS/pmaports/-/raw/c1a3d0667856ff40723ec3b731dd47165df335e9/device/testing/firmware-kobo-clara/hwcfg.bin";
      hash = lib.fakeHash;
    };
    # https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/firmware-kobo-clara/APKBUILD
    installPhase = ''
      le32() {
        printf "%08x" "$1" | sed -E 's/(..)(..)(..)(..)/\\x\4\\x\3\\x\2\\x\1/'
      }
      prepend_header() {
        length=$(stat -L -c %s "$1")
        dd bs=496 count=1 if=/dev/zero
        printf '\xff\xf5\xaf\xff\x78\x56\x34\x12%b\x00\x00\x00\x00' "$(le32 "$length")"
        cat "$1"
      }
      mkdir -p "$out/share/firmware/kobo-clara"
      prepend_header hwcfg.bin > "$out/share/firmware/kobo-clara/hwcfg+header.bin"
      prepend_header upgrade/mx6sll-ntx/ntxfw-E60K00+header.bin > "$out/share/firmware/kobo-clara/ntxfw-E60K00+header.bin"
    '';
  };
  linux_koboClara = pkgs.linux_latest.override {
    kernelPatches = [
      {
        name = "linux_6_8";
        patch = pkgs.fetchpatch {
          url = "https://github.com/torvalds/linux/compare/e8f897f4afef0031fe618a8e94127a0934896aba...akemnade:linux:941e725995136bdb897f793607a3af0a915a96f8.patch";
          hash = lib.fakeHash;
        };
      }
    ];
    ignoreConfigErrors = false;
    structuredExtraConfig = with lib.kernel; {
      KERNEL_LZO = yes;
      NO_HZ_IDLE = yes;
      HIGH_RES_TIMERS = yes;
      LOG_BUF_SHIFT = 18;
      CMA = yes;
      RELAY = yes;
      PERF_EVENTS = yes;
      ARCH_MULTI_V6 = yes;
      ARCH_MXC = yes;
      MACH_MX31LILLY = yes;
      MACH_MX31LITE = yes;
      MACH_PCM037 = yes;
      MACH_PCM037_EET = yes;
      MACH_MX31_3DS = yes;
      MACH_MX31MOBOARD = yes;
      MACH_QONG = yes;
      MACH_ARMADILLO5X0 = yes;
      MACH_KZM_ARM11_01 = yes;
      MACH_IMX31_DT = yes;
      MACH_IMX35_DT = yes;
      MACH_PCM043 = yes;
      MACH_MX35_3DS = yes;
      MACH_VPR200 = yes;
      SOC_IMX50 = yes;
      SOC_IMX51 = yes;
      SOC_IMX53 = yes;
      SOC_IMX6Q = yes;
      SOC_IMX6SL = yes;
      SOC_IMX6SLL = yes;
      SOC_IMX6SX = yes;
      SOC_IMX6UL = yes;
      SOC_IMX7D = yes;
      SOC_IMX7ULP = yes;
      SOC_VF610 = yes;
      SMP = yes;
      ARM_PSCI = yes;
      HIGHMEM = yes;
      FORCE_MAX_ZONEORDER = 14;
      ARM_APPENDED_DTB = yes;
      ARM_ATAG_DTB_COMPAT = yes;
      CMDLINE = "console=ttymxc0,115200";
      KEXEC = yes;
      CPU_FREQ = yes;
      CPU_FREQ_STAT = yes;
      CPU_FREQ_DEFAULT_GOV_ONDEMAND = yes;
      CPU_FREQ_GOV_POWERSAVE = yes;
      CPU_FREQ_GOV_USERSPACE = yes;
      CPU_FREQ_GOV_CONSERVATIVE = yes;
      CPUFREQ_DT = yes;
      ARM_IMX6Q_CPUFREQ = yes;
      ARM_IMX_CPUFREQ_DT = yes;
      CPU_IDLE = yes;
      ARM_CPUIDLE = yes;
      ARM_PSCI_CPUIDLE = yes;
      VFP = yes;
      NEON = yes;
      PM_DEBUG = yes;
      PM_TEST_SUSPEND = yes;
      MODULES = yes;
      MODULE_UNLOAD = yes;
      MODVERSIONS = yes;
      MODULE_SRCVERSION_ALL = yes;
      PACKET = yes;
      INET = yes;
      IP_PNP = yes;
      IP_PNP_DHCP = yes;
      NETFILTER = yes;
      CFG80211 = yes;
      MAC80211 = yes;
      RFKILL = yes;
      RFKILL_INPUT = yes;
      DEVTMPFS = yes;
      DEVTMPFS_MOUNT = yes;
      IMX_WEIM = yes;
      BLK_DEV_LOOP = yes;
      BLK_DEV_RAM = yes;
      BLK_DEV_RAM_SIZE = 65536;
      EEPROM_AT24 = yes;
      EEPROM_AT25 = yes;
      BLK_DEV_SD = yes;
      SCSI_CONSTANTS = yes;
      SCSI_LOGGING = yes;
      SCSI_SCAN_ASYNC = yes;
      NETDEVICES = yes;
      CS89x0 = yes;
      CS89x0_PLATFORM = yes;
      INPUT_EVDEV = yes;
      KEYBOARD_GPIO = yes;
      KEYBOARD_SNVS_PWRKEY = yes;
      KEYBOARD_IMX = yes;
      INPUT_TOUCHSCREEN = yes;
      TOUCHSCREEN_CYTTSP5 = yes;
      INPUT_MISC = yes;
      SERIO_SERPORT = module;
      SERIAL_IMX = yes;
      SERIAL_IMX_CONSOLE = yes;
      SERIAL_FSL_LPUART = yes;
      SERIAL_FSL_LPUART_CONSOLE = yes;
      SERIAL_DEV_BUS = yes;
      I2C_CHARDEV = yes;
      I2C_MUX = yes;
      I2C_MUX_GPIO = yes;
      I2C_ALGOPCF = module;
      I2C_ALGOPCA = module;
      I2C_GPIO = yes;
      I2C_IMX = yes;
      SPI_FSL_QUADSPI = yes;
      SPI_GPIO = yes;
      SPI_IMX = yes;
      SPI_FSL_DSPI = yes;
      GPIO_SYSFS = yes;
      GPIO_MXC = yes;
      RN5T618_POWER = module;
      POWER_RESET = yes;
      POWER_RESET_SYSCON = yes;
      POWER_RESET_SYSCON_POWEROFF = yes;
      POWER_SUPPLY = yes;
      SENSORS_MC13783_ADC = yes;
      SENSORS_GPIO_FAN = yes;
      SENSORS_IIO_HWMON = yes;
      SENSORS_TPS6518X = module;
      THERMAL = yes;
      THERMAL_STATISTICS = yes;
      THERMAL_WRITABLE_TRIPS = yes;
      CPU_THERMAL = yes;
      IMX_THERMAL = yes;
      WATCHDOG = yes;
      RN5T618_WATCHDOG = yes;
      IMX2_WDT = yes;
      MFD_RN5T618 = yes;
      MFD_TPS6518X = module;
      REGULATOR_FIXED_VOLTAGE = yes;
      REGULATOR_ANATOP = yes;
      REGULATOR_GPIO = yes;
      REGULATOR_MC13783 = yes;
      REGULATOR_MC13892 = yes;
      REGULATOR_RN5T618 = yes;
      REGULATOR_TPS6518X = module;
      IMX_IPUV3_CORE = yes;
      DRM = yes;
      DRM_PANEL_LVDS = yes;
      DRM_PANEL_SIMPLE = yes;
      DRM_PANEL_SEIKO_43WVF1G = yes;
      DRM_DW_HDMI_CEC = yes;
      DRM_MXSFB = yes;
      DRM_MXC_EPDC = module;
      FB_MODE_HELPERS = yes;
      LCD_CLASS_DEVICE = yes;
      LCD_L4F00242T03 = yes;
      LCD_PLATFORM = yes;
      BACKLIGHT_PWM = yes;
      BACKLIGHT_LM3630A = module;
      BACKLIGHT_GPIO = yes;
      FRAMEBUFFER_CONSOLE = yes;
      HID_MULTITOUCH = yes;
      USB = yes;
      USB_ANNOUNCE_NEW_DEVICES = yes;
      USB_EHCI_HCD = yes;
      USB_EHCI_MXC = yes;
      USB_STORAGE = yes;
      USB_CHIPIDEA = yes;
      USB_CHIPIDEA_UDC = yes;
      USB_CHIPIDEA_HOST = yes;
      USB_SERIAL = module;
      USB_SERIAL_GENERIC = yes;
      USB_SERIAL_FTDI_SIO = module;
      USB_SERIAL_OPTION = module;
      USB_TEST = module;
      USB_EHSET_TEST_FIXTURE = module;
      NOP_USB_XCEIV = yes;
      USB_MXS_PHY = yes;
      USB_GADGET = yes;
      USB_FSL_USB2 = yes;
      USB_CONFIGFS = module;
      USB_CONFIGFS_SERIAL = yes;
      USB_CONFIGFS_ACM = yes;
      USB_CONFIGFS_OBEX = yes;
      USB_CONFIGFS_NCM = yes;
      USB_CONFIGFS_ECM = yes;
      USB_CONFIGFS_ECM_SUBSET = yes;
      USB_CONFIGFS_RNDIS = yes;
      USB_CONFIGFS_EEM = yes;
      USB_CONFIGFS_MASS_STORAGE = yes;
      USB_CONFIGFS_F_LB_SS = yes;
      USB_CONFIGFS_F_FS = yes;
      USB_CONFIGFS_F_HID = yes;
      USB_CONFIGFS_F_PRINTER = yes;
      USB_ZERO = module;
      USB_ETH = module;
      USB_G_NCM = module;
      USB_GADGETFS = module;
      USB_FUNCTIONFS = module;
      USB_MASS_STORAGE = module;
      USB_G_SERIAL = module;
      MMC = yes;
      MMC_SDHCI = yes;
      MMC_SDHCI_PLTFM = yes;
      MMC_SDHCI_ESDHC_IMX = yes;
      NEW_LEDS = yes;
      LEDS_CLASS = yes;
      LEDS_GPIO = yes;
      LEDS_PWM = yes;
      LEDS_TRIGGERS = yes;
      LEDS_TRIGGER_TIMER = yes;
      LEDS_TRIGGER_ONESHOT = yes;
      LEDS_TRIGGER_HEARTBEAT = yes;
      LEDS_TRIGGER_BACKLIGHT = yes;
      LEDS_TRIGGER_GPIO = yes;
      LEDS_TRIGGER_DEFAULT_ON = yes;
      RTC_CLASS = yes;
      RTC_INTF_DEV_UIE_EMUL = yes;
      RTC_DRV_MXC = yes;
      RTC_DRV_MXC_V2 = yes;
      RTC_DRV_SNVS = yes;
      RTC_DRV_RC5T619 = module;
      DMADEVICES = yes;
      DMA_CMA = yes;
      FSL_EDMA = yes;
      IMX_SDMA = yes;
      MXS_DMA = yes;
      DMATEST = module;
      STAGING_MEDIA = yes;
      COMMON_CLK_PWM = yes;
      IIO = yes;
      MMA8452 = yes;
      IMX7D_ADC = yes;
      VF610_ADC = yes;
      RN5T618_ADC = module;
      PWM = yes;
      PWM_FSL_FTM = yes;
      PWM_IMX27 = yes;
      PWM_IMX_TPM = yes;
      NVMEM_IMX_OCOTP = yes;
      NVMEM_VF610_OCOTP = yes;
      NVMEM_SNVS_LPGPR = yes;
      TEE = yes;
      OPTEE = yes;
      SIOX = module;
      SIOX_BUS_GPIO = module;
      EXT2_FS = yes;
      EXT3_FS = yes;
      QUOTA = yes;
      QUOTA_NETLINK_INTERFACE = yes;
      AUTOFS4_FS = yes;
      FUSE_FS = yes;
      JOLIET = yes;
      ZISOFS = yes;
      MSDOS_FS = module;
      VFAT_FS = yes;
      JFFS2_FS = yes;
      UBIFS_FS = yes;
      SECURITYFS = yes;
      CRYPTO_DEV_FSL_CAAM = yes;
      CRYPTO_DEV_SAHARA = yes;
      CRYPTO_DEV_MXS_DCP = yes;
      CRC_CCITT = module;
      CRC_T10DIF = yes;
      CRC7 = module;
      LIBCRC32C = module;
      CMA_SIZE_MBYTES = 64;
      PRINTK_TIME = yes;
      MAGIC_SYSRQ = yes;
      DEBUG_FS = yes;
      PROVE_LOCKING = yes;
      TUN = module;
      USB_USBNET = module;
      NF_CONNTRACK = module;
      NF_CT_NETLINK = module;
      NF_CT_NETLINK_TIMEOUT = module;
      NF_TABLES = module;
      NFT_CT = module;
      NFT_LOG = module;
      NFT_LIMIT = module;
      NFT_MASQ = module;
      NFT_REDIR = module;
      NFT_NAT = module;
      NFT_TUNNEL = module;
      NFT_COMPAT = module;
      NFT_SOCKET = module;
      NFT_TPROXY = module;
      NFT_SYNPROXY = module;
      NFT_FWD_NETDEV = module;
      NETFILTER_XTABLES = module;
      NETFILTER_XT_TARGET_LOG = module;
      NETFILTER_XT_NAT = module;
      NETFILTER_XT_TARGET_NFLOG = module;
      NETFILTER_XT_TARGET_MASQUERADE = module;
      NETFILTER_XT_TARGET_TEE = module;
      NETFILTER_XT_TARGET_TCPMSS = module;
      NETFILTER_XT_MATCH_ADDRTYPE = module;
      BLK_DEV_DM = module;
      DM_CRYPT = module;
      CRYPTO_CBC = yes;
      CRYPTO_CTS = module;
      CRYPTO_ECB = yes;
      CRYPTO_LRW = module;
      CRYPTO_PCBC = module;
      CRYPTO_XTS = module;
      CRYPTO_XCBC = module;
      CRYPTO_MD5 = yes;
      CRYPTO_MICHAEL_MIC = yes;
      CRYPTO_RMD128 = module;
      CRYPTO_RMD160 = module;
      CRYPTO_RMD256 = module;
      CRYPTO_RMD320 = module;
      CRYPTO_SHA256 = yes;
      CRYPTO_TGR192 = module;
      CRYPTO_WP512 = module;
      MFD_NTXEC = yes;
      PWM_NTXEC = module;
      TOUCHSCREEN_ZFORCE = module;
      BRCMFMAC = module;
      BRCMFMAC_SDIO = yes;
      TOUCHSCREEN_EKTF2127 = module;
      RTC_DRV_NTXEC = module;
      MFD_SY7636 = module;
      REGULATOR_SY7636 = module;
      SENSORS_SY7636 = module;
      GPIO_BD71815 = module;
      GPIO_BD71828 = module;
      MFD_ROHM_BD71828 = module;
      REGULATOR_BD71815 = module;
      REGULATOR_BD71828 = module;
      COMMON_CLK_BD718XX = module;
    };
  };
}
