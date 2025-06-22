{ config
, pkgs
, lib
, inputs
, ...
}:

{
  imports = [
    ./options.nix
    ./zsh.nix
    ./fish.nix
  ];
  manual.json.enable = !config.minimal;
  services.gpg-agent = {
    enable = !config.minimal;
    enableSshSupport = true;
    maxCacheTtl = 72000;
    maxCacheTtlSsh = 72000;
    pinentryPackage = if config.minimal then pkgs.pinentry.tty else pkgs.pinentry.qt;
  };
  home.shellAliases = {
    s = "sudo -A";
    se = "sudo -AE";
    l = "lsd";
    # la = "lsd -A";
    # ll = "lsd -l";
    g = "git";
    gp = "git push";
    gr = "git rebase";
    gri = "git rebase -i";
    grc = "git rebase --continue";
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
      package = (pkgs.nnn.override { withNerdIcons = true; }).overrideAttrs (oldAttrs: {
        # no need to add makeWrapper to nativeBuildInputs as home-manager does it already
        postInstall =
          let nnnArchiveRegex = "\\.(${lib.strings.concatStringsSep "|" [
            "7z" "a" "ace" "alz" "arc" "arj" "bz" "bz2" "cab" "cpio" "deb" "gz" "jar" "lha" "lz" "lzh" "lzma" "lzo" "rar" "rpm" "rz" "t7z" "tar" "tbz" "tbz2" "tgz" "tlz" "txz" "tZ" "tzo" "war" "xpi" "xz" "Z" "zip"
          ]})$"; in ''
            wrapProgram $out/bin/nnn ${lib.escapeShellArgs [
              "--set" "GUI" "1"
              "--set" "NNN_OPENER" "${pluginSrc}/nuke"
              "--set" "NNN_ARCHIVE" nnnArchiveRegex
              # -a: auto create fifo file
              # -c: use NNN_OPENER
              # -x: x server features
              "--add-flags" "-a -c -x"
            ]}
        '';
      });
      extraPackages = with pkgs; [
        # utils
        gnused mktemp fzf coreutils-full findutils xdg-utils whois curl
        file unzip gnutar man
        # for preview
        # exa - TODO: replace with eza wrapper?
        libarchive atool
        # for opening
        p7zip
      ] ++ lib.optionals (!config.minimal) [
        gnupg odt2txt w3m sshfs trash-cli unrar-wrapper
        mediainfo rclone bat glow
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
    home-manager.enable = true;
    # i only use this as a login shell
    bash = {
      enable = !config.minimal;
      initExtra = ''
        bind -x '"\C-r": __atuin_history'
        export ATUIN_NOBIND=true
      '';
    };
    git = {
      enable = !config.minimal;
      package = pkgs.gitAndTools.gitFull;
      delta.enable = true;
      extraConfig = {
        commit.gpgsign = true;
        # disable the atrocious gui password prompt
        core.askPass = "";
        # ...and prefer getting passwords from libsecret (and storing them there)
        credential.helper = "${pkgs.gitAndTools.gitFull}/bin/git-credential-libsecret";
        init.defaultBranch = "master";
        # no need for git pust -u origin <branch>
        push.autoSetupRemote = true;
        # allow different upstream branch name
        push.default = "upstream";
      };
      lfs.enable = true;
    };
    bat = {
      enable = !config.minimal;
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
      enable = !config.minimal;
      compression = true;
    };
    tmux = {
      enable = true;
      clock24 = true;
      customPaneNavigationAndResize = true;
      keyMode = "vi";
    };
    gpg = {
      enable = !config.minimal;
      homedir = "${config.xdg.dataHome}/gnupg";
      mutableKeys = true;
      mutableTrust = true;
    };
    readline = {
      enable = true;
      variables.editing-mode = "vi";
      variables.show-mode-in-prompt = true;
    };
    nix-index = {
      enable = !config.minimal;
      # don't add pkgs.nix to PATH
      # use the nix that's already in PATH
      # (because I use nix plugins and plugins are nix version-specific)
      package = pkgs.nix-index-unwrapped;
    };
    #neomutt = {
    #  enable = true;
    #  sidebar.enable = true;
    #  vimKeys = true;
    #};
    alot = {
      enable = !config.minimal;
      settings = {
        handle_mouse = true;
        initial_command = "search tag:inbox AND NOT tag:killed";
        prefer_plaintext = true;
      };
    };
    msmtp.enable = !config.minimal;
    notmuch = {
      enable = !config.minimal;
      # syncing is handled by home-daemon now
      #hooks.preNew = ''
      #  ${config.services.mbsync.package}/bin/mbsync --all || ${pkgs.coreutils}/bin/true
      #'';
    };
    mbsync.enable = !config.minimal;
  };
  #services.mbsync.enable = true;
  # TODO: see https://github.com/pazz/alot/issues/1632
  home.file.".mailcap" = lib.mkIf (!config.minimal) {
    text = ''
      text/html;  ${pkgs.w3m}/bin/w3m -dump -o document_charset=%{charset} -o display_link_number=1 '%s'; nametemplate=%s.html; copiousoutput
    '';
  };

  home.file.".cache/nix-index/files" = lib.mkIf (!config.minimal) {
    source =
      assert config.xdg.cacheHome == "${config.home.homeDirectory}/.cache";
      inputs.nix-index-database.packages.${pkgs.system}.nix-index-database;
  };

  systemd.user.tmpfiles.rules = lib.mkIf (!config.minimal)
  (builtins.map (file: "r!  \"/home/${config.home.username}/${file}\"") [
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
  ]);

  home.packages = with pkgs; [
    rclone sshfs fuse
    file jq python3Full killall
    comma nix-output-monitor
    unzip p7zip
  ] ++ lib.optionals (!config.minimal) [
    appimage-run unrar-wrapper
  ];
}
