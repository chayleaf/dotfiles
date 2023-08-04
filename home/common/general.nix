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
    g = "git";
    gp = "git push";
    gpuo = "git push -u origin";
    gr = "git rebase";
    gri = "git rebase -i";
    gc = "git commit";
    gca = "git commit --amend";
    gm = "git merge";
  };

  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = false;
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
        gnused mktemp fzf coreutils-full findutils xdg-utils gnupg whois curl
        file mediainfo unzip gnutar man rclone sshfs trash-cli
        # for preview
        exa bat
        libarchive atool
        glow w3m
        # for opening
        p7zip unrar-wrapper odt2txt
      ];
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
        # disable the atrocious gui password prompt
        core.askPass = "";
        # ...and prefer getting passwords from libsecret (and storing them there)
        credential.helper = "${pkgs.gitAndTools.gitFull}/bin/git-credential-libsecret";
        init.defaultBranch = "master";
      };
      lfs.enable = true;
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
    readline = {
      enable = true;
      variables.editing-mode = "vi";
    };
    nix-index = {
      enable = true;
      # don't add pkgs.nix to PATH
      # use the nix that's already in PATH
      # (because I use nix plugins and plugins are nix version-specific)
      package = pkgs.nix-index-unwrapped;
    };
  };

  systemd.user.timers.nix-index = {
    Install.WantedBy = [ "timers.target" ];
    Unit = {
      Description = "Update nix-index";
      PartOf = [ "nix-index.service" ];
    };
    Timer = {
      OnCalendar = "Mon *-*-* 00:00:00";
      RandomizedDelaySec = 600;
      Persistent = true;
    };
  };
  systemd.user.services.nix-index = {
    Unit.Description = "Update nix-index";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.programs.nix-index.package}/bin/nix-index";
      Environment = [ "PATH=/home/${config.home.username}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin" ];
      TimeoutStartSec = 1800;
    };
  };

  systemd.user.tmpfiles.rules = builtins.map (file: "r!  \"/home/${config.home.username}/${file}\"") [
    ".local/share/clipman.json"
    ".local/state/lesshst" # I don't need less search history to persist across boots...
    ".Xauthority"
    ".sqlite_history"
    ".local/share/krunnerstaterc"
    ".local/share/user-places.xbel.bak"
    ".local/share/user-places.xbel.tbcache"
    ".config/mimeapps.list"
    ".config/ncmpcpp/error.log"
    ".config/mozc/.server.lock"
    ".config/mozc/.session.ipc"
    ".config/mozc/.registry.db" # usage stats (seemingly disabled on my machine)
    ".config/looking-glass/imgui.ini"
    ".config/QtProject.conf"
    ".steampid"
    ".steampath"
    ".config/.xash_id"
    ".config/proton.conf"
    ".local/state/nvim/lsp.log" # this is never cleared...
    ".config/pavucontrol.ini"
  ] ++ builtins.map (dir: "e!  \"/home/${config.home.username}/${dir}/\" - - - 60d") [
    ".cache"
    ".local/share/qalculate"
    ".local/share/nvfetcher"
    ".gradle"
    ".openjfx"
    ".mono"
    ".local/share/Trash"
    ".config/wireshark"
    ".config/qt5ct"
    ".config/procps"
    ".config/neofetch"
    ".config/matplotlib"
    ".local/share/arti"
    # I use this dir as dumping grounds for random stuff
    "tmp"
    # games stuff
    ".local/share/vulkan"
    ".steam"
    ".paradoxlauncher"
    ".local/share/StardewValley" # only logs here
    ".local/share/GOG.com"
    ".local/share/Paradox Interactive/launcher-v2"
    # faf
    ".com.faforever.client.FafClientApplication"
    ".org.testfx.toolkit.PrimaryStageApplication"
    ".faforever/logs"
    # whatever this is (has a single file named cookie)
    ".config/pulse"
    # Nextcloud logs
    ".config/Nextcloud/logs"
    ".local/share/Nextcloud"
    # this might seem useful, but it's only for temporary dbus files actually
    ".config/fcitx"
    ".config/ibus"
    # fcitx themes (come on would I ever theme something non-declaratively)
    ".local/share/fcitx5"
    # RGB tooling that I barely use
    ".config/OpenRGB"
    ".config/ario"
    # I don't use Firefox, I use Librewolf
    ".mozilla"
    # dev stuff
    ".local/share/tvix"
    ".cargo"
    ".npm"
    # just when I thought ~ pollution couldn't get worse...
    "go"
    # android studio and related
    ".local/share/android"
    ".local/share/Google"
    ".java"
    ".local/share/Sentry"
    ".android/cache"
    ".m2"
    # chromium
    ".config/chromium"
    ".config/cef_user_data"
    ".pki"
    # a lib used by glow
    ".local/share/charm"
    # I barely use FreeCAD, don't need its files
    ".config/FreeCAD"
    ".local/share/FreeCAD"
    # some useless gui config
    ".config/gtk-2.0"
    ".config/gtk-3.0"
    ".config/kde.org"
    # QtWebEngine cache
    ".local/share/Anki"
    # kde connect contacts
    ".local/share/kpeoplevcard"
    # repl history
    ".local/share/nix"
    # iwctl history
    ".local/share/iwctl"
    # non-home-manager-managed files
    ".local/share/applications"
    ".local/share/icons"
    ".local/share/mime"
    ".config/autostart"
    # logs
    ".local/share/xorg"
    # if I forgot it, it probably wasn't important
    "Downloads"
  ] ++ builtins.map (dir: "x  \"/home/${config.home.username}/${dir}/\"") [
    # WHY DOES THIS KEEP PART OF THE CONFIG
    ".cache/keepassxc"
  ];

  home.packages = with pkgs; [
    rclone sshfs fuse
    file jq python3Full killall
    appimage-run comma nix-output-monitor
    unzip p7zip unrar-wrapper
  ];
}
