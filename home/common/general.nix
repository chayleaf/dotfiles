{ config, pkgs, lib, ... }:
{
  imports = [
    ./options.nix
    ./zsh.nix
    ./fish.nix
  ];
  manual.json.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    maxCacheTtl = 72000;
    maxCacheTtlSsh = 72000;
  };
  home.shellAliases = {
    s = "sudo -A";
    se = "sudo -AE";
    l = "lsd";
  };

  programs = {
    atuin = {
      enable = true;
      settings = {
        update_check = false;
      };
    };
    nnn = let pluginSrc = "${pkgs.nnn.src}/plugins"; in {
      enable = true;
      package = (pkgs.nnn.override ({ withNerdIcons = true; })).overrideAttrs (oldAttrs: {
        # no need to add makeWrapper to nativeBuildInputs as home-manager does it already
        postInstall =
          let nnnArchiveRegex = "\\.(${lib.strings.concatStringsSep "|" [
            "7z" "a" "ace" "alz" "arc" "arj" "bz" "bz2" "cab" "cpio" "deb" "gz" "jar" "lha" "lz" "lzh" "lzma" "lzo" "rar" "rpm" "rz" "t7z" "tar" "tbz" "tbz2" "tgz" "tlz" "txz" "tZ" "tzo" "war" "xpi" "xz" "Z" "zip"
          ]})$"; in with lib; with strings; ''
          wrapProgram $out/bin/nnn \
            --set GUI 1 \
            --set NNN_OPENER ${escapeShellArg "${pluginSrc}/nuke"} \
            --set NNN_ARCHIVE ${escapeShellArg nnnArchiveRegex} \
            --add-flags ${
              # -a: auto create fifo file
              # -c: use NNN_OPENER
              # -x: x server features
              escapeShellArg "-a -c -x"
            }
        '';
      });
      extraPackages = with pkgs; [
        # utils
        gnused mktemp fzf coreutils-full findutils xdg-utils git gnupg whois curl
        file mediainfo unzip gnutar man rclone sshfs trash-cli
        # drag & drop
        xdragon
        # xembed
        tabbed
        # for preview
        exa bat
        ffmpeg ffmpegthumbnailer nsxiv imagemagick
        libarchive atool
        libreoffice poppler_utils fontpreview djvulibre
        glow w3m
        # for opening
        p7zip unrar-wrapper zathura odt2txt
      ] ++ lib.optionals (!config.programs.mpv.enable) [ mpv ];
      plugins = {
        src = pluginSrc;
        mappings = {
          p = "-preview-tui";
          P = "fzplug";
          D = "dragdrop";
          c = "-chksum";
          d = "-diffs";
          f = "fzopen";
          s = "suedit"; 
          x = "togglex";
          u = "umounttree";
        };
      };
    };
    neomutt = {
      enable = true;
      sidebar.enable = true;
      vimKeys = true;
    };
    home-manager.enable = true;
    # i only use this as a login shell
    bash = {
      enable = true;
      initExtra = ''
        bind -x '"\C-r": __atuin_history'
        export ATUIN_NOBIND=true
      '';
    };
    git = {
      enable = true;
      package = pkgs.gitAndTools.gitFull;
      delta.enable = true;
      extraConfig = {
        core.askPass = "";
        credential.helper = "${pkgs.gitAndTools.gitFull}/bin/git-credential-libsecret";
      };
    };
    bat = {
      enable = true;
    };
    bottom = {
      enable = true;
      settings = {
        flags.network_use_bytes = true;
        flags.enable_gpu_memory = true;
      };
    };
    lsd = {
      enable = true;
      settings = {
        date = "+%Y-%m-%d %H:%M:%S";
        permission = "octal";
        size = "short";
      };
    };
    ssh = {
      enable = true;
      compression = true;
    };
    tmux = {
      enable = true;
      clock24 = true;
      customPaneNavigationAndResize = true;
      keyMode = "vi";
    };
    gpg = {
      enable = true;
      homedir = "${config.xdg.dataHome}/gnupg";
      mutableKeys = true;
      mutableTrust = true;
    };
    nix-index.enable = true;
    readline = {
      enable = true;
      variables.editing-mode = "vi";
    };
  };

  home.packages = with pkgs; [
    rclone sshfs fuse
    file jq python3Full killall
    appimage-run comma nix-output-monitor
  ];
}
