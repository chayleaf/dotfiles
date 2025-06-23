{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # uuids.enc = "e2abdea5-71dc-4a9e-aff3-242117342d60";
  uuids.boot = "49b5ab26-a8f4-4873-a235-da2b3608e870";
  uuids.swap = "b7eb326b-69d8-4347-a2dc-549ec6201e7f";
  uuids.root = "99cda95f-f866-42a0-883f-343ad3662920";
  parts = builtins.mapAttrs (k: v: "/dev/disk/by-uuid/${v}") uuids;
in

{
  imports = [
    ../hardware/kobo-clara
    ../hosts/ereader
  ];

  fonts.enableDefaultPackages = false;
  # defaults without noto-fonts-color-emoji
  fonts.packages = with pkgs; [
    dejavu_fonts
    freefont_ttf
    gyre-fonts # TrueType substitutes for standard PostScript fonts
    liberation_ttf
    unifont
  ];

  nixpkgs.overlays = [
    (
      self: super:
      let
        overrideFfmpeg =
          ffmpeg:
          ffmpeg.override {
            withAlsa = false;
            withJack = false;
            withMp3lame = false;
            withOgg = false;
            withOpus = false;
            withPulse = false;
            withSpeex = false;
            withVaapi = false;
            withVdpau = false;
            withVorbis = false;
          };
      in
      {
        ffmpeg = overrideFfmpeg super.ffmpeg;
        waybar = super.waybar.override {
          hyprlandSupport = false;
          jackSupport = false;
          mpdSupport = false;
          mprisSupport = false;
          pipewireSupport = false;
          pulseSupport = false;
          sndioSupport = false;
          cavaSupport = false;
          wireplumberSupport = false;
        };
        awesome = super.awesome.overrideAttrs (old: {
          # broken cross tests
          doCheck = false;
        });
        # ffmpeg isnt actually used in wlroots anymore, remove the useless dependency
        wlroots_0_17 = super.wlroots_0_17.overrideAttrs (old: {
          buildInputs = builtins.filter (x: x.pname != "ffmpeg") old.buildInputs;
        });
        # heif/avif support isnt worth an extra rust dependency
        imagemagick = super.imagemagick.override {
          libheifSupport = false;
        };
        jasper = super.jasper.override {
          enableHEIFCodec = false;
        };
        # no audio, so no need to bring in the audio libs
        SDL2 = super.SDL2.override {
          alsaSupport = false;
          pipewireSupport = false;
          pulseaudioSupport = false;
        };
        openalSoft = super.openalSoft.override {
          alsaSupport = false;
          pipewireSupport = false;
          pulseSupport = false;
        };
        openal = super.openal.override {
          alsaSupport = false;
          pipewireSupport = false;
          pulseSupport = false;
        };
        # luajit has to be built on a system with 32-bit pointer width when targeting 32-bit systems
        luajit =
          (import inputs.nixpkgs { system = "i686-linux"; }).pkgsCross.armv7l-hf-multiplatform.luajit;
        # fix cross https://github.com/NixOS/nixpkgs/pull/328919/
        texinfo = super.texinfo.overrideAttrs (old: {
          configureFlags =
            old.configureFlags
            ++ lib.optional (
              self.stdenv.hostPlatform != self.stdenv.buildPlatform
            ) "texinfo_cv_sys_iconv_converts_euc_cn=yes";
        });
        koreader = super.koreader.overrideAttrs (old: {
          src = self.fetchurl {
            url = "https://github.com/koreader/koreader/releases/download/v${old.version}/koreader-${old.version}-armhf.deb";
            hash = "sha256-LgeWQcHm5Qq/7MUuidjily0WsOFZAWGWeO52jNHWKMw=";
          };
          meta = old.meta // {
            platforms = [ "armv7l-linux" ];
          };
        });
      }
    )
  ];

  networking.wireless.iwd.enable = true;

  fileSystems =
    let
      neededForBoot = true;
    in
    {
      "/" = {
        device = "none";
        fsType = "tmpfs";
        inherit neededForBoot;
        options = [
          "defaults"
          "size=2G"
          "mode=755"
        ];
      };
      "/persist" = {
        device = parts.root;
        fsType = "btrfs";
        inherit neededForBoot;
        options = [
          "discard=async"
          "compress=zstd:15"
        ];
      };
      "/boot" = {
        device = parts.boot;
        fsType = "ext4";
      };
    };

  swapDevices = [ { device = parts.swap; } ];
  boot.resumeDevice = parts.swap;

  system.build.rootfsImage = pkgs.callPackage "${pkgs.path}/nixos/lib/make-btrfs-fs.nix" {
    storePaths = config.system.build.toplevel;
    compressImage = true;
    volumeLabel = "NIX_ROOTFS";
    uuid = uuids.root;
  };
  system.build.bootFiles = pkgs.runCommand "kobo-clara-boot-files" { } ''
    mkdir -p "$out"
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d $out -g 0
  '';

  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      {
        directory = /home/${config.common.mainUsername};
        user = config.common.mainUsername;
        group = "users";
        mode = "0700";
      }
      {
        directory = /root;
        mode = "0700";
      }
      { directory = /nix; }
      {
        directory = /secrets;
        mode = "0000";
      }
    ];
  };
}
