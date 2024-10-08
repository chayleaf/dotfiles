{ pkgs
, lib
, ...
}:

{
  uboot = pkgs.buildUBoot {
    defconfig = "mx6sllclarahd_defconfig";
    extraConfig = ''
      CONFIG_FASTBOOT_OEM_RUN=y
      CONFIG_ENV_IS_IN_EXT4=y
      CONFIG_ENV_IS_IN_MMC=n
      CONFIG_ENV_EXT4_INTERFACE=mmc
      CONFIG_ENV_EXT4_DEVICE_AND_PART=0:1
      CONFIG_ENV_EXT4_FILE=/uboot.env
      CONFIG_BOOTCOMMAND="${builtins.replaceStrings [ "\n" ] [ "; " ] ''
      detect_clara_rev
      run distro_bootcmd
      setenv stdin usbacm
      setenv stdout usbacm
      setenv stderr usbacm
      ''};"
    '';
      # fastboot 0
    src = pkgs.fetchFromGitHub {
      owner = "akemnade";
      repo = "u-boot-fslc";
      hash = "sha256-MUAiiXTfxt/o/6rnoI7A76IMRPDUhXodjnguKwQKrVs=";
      rev = "3247fa27aed27bb5ac24bd9966fd7dadd9c4c373";
    };
    version = "2023.10";
    extraMeta.platforms = [ "armv7l-linux" ];
    filesToInstall = [ "u-boot-dtb.imx" ];
  };
  linux = (pkgs.buildLinux rec {
    version = "6.9.0";
    modDirVersion = lib.versions.pad 3 version;

    src = pkgs.fetchFromGitHub {
      owner = "akemnade";
      repo = "linux";
      rev = "4b0c49001732b93f6787c44e090b8e8f72e6fe6a";
      hash = "sha256-rCiznEHDqrOW+CEI1I9HdHNSsVYCb7iJGE+7PKJ8H6A=";
    };

    defconfig = "kobo_defconfig";
  }).overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.lzop ];
  });
}
