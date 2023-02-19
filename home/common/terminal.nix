{ config, pkgs, lib, ... }:
let
  supportTerminal = (term: builtins.elem term config.terminals);
  getTerminalBin = (term: ({
    alacritty = "${pkgs.alacritty}/bin/alacritty";
    foot = "${pkgs.foot}/bin/footclient";
    kitty = "${pkgs.kitty}/bin/kitty";
    urxvt = "${pkgs.rxvt-unicode-emoji}/bin/urxvt";
  }).${term});
  color = builtins.elemAt config.colors.base;
  hex = (x: if builtins.isFunction x then (y: "#" + (x y)) else ("#" + x));
  shell = lib.mkIf config.termShell.enable config.termShell.path;
in {
  imports = [ ./options.nix ];
  terminalBin = getTerminalBin (builtins.head config.terminals);
  terminalBinX = getTerminalBin (lib.lists.findFirst (term: term != "foot") null config.terminals);
  colors = {
    base = [
      "523b3f" # black
      "e66e6e" # red
      "8cbf73" # green
      "ebbe5f" # yellow
      "5968b3" # blue
      "a64999" # magenta
      "77c7c2" # cyan
      "f0e4e6" # white
      "6b4d52"
      "e66e6e"
      "8cbf73"
      "ebbe5f"
      "5968b3"
      "a64999"
      "77c7c2"
      "f7f0f1"
    ];
    foreground = "ebdadd";
    background = "24101a";
    alpha = 0.75;
  };
  programs.alacritty = {
    enable = supportTerminal "alacritty";
    # https://github.com/alacritty/alacritty/blob/master/alacritty.yml
    settings = {
      window.opacity = config.colors.alpha;
      font.normal.family = "Noto Sans Mono";
      font.size = 16;
      shell.program = shell;
      colors.primary.background = hex config.colors.background;
      colors.primary.foreground = hex config.colors.foreground;
      colors.normal = {
        black = hex color 0;
        red = hex color 1;
        green = hex color 2;
        yellow = hex color 3;
        blue = hex color 4;
        magenta = hex color 5;
        cyan = hex color 6;
        white = hex color 7;
      };
      colors.bright = {
        black = hex color 8;
        red = hex color 9;
        green = hex color 10;
        yellow = hex color 11;
        blue = hex color 12;
        magenta = hex color 13;
        cyan = hex color 14;
        white = hex color 15;
      };
    };
  };
  programs.urxvt = {
    # default shell can't be changed... I can create a wrapper, but fuck that
    # symbols nerd font mono doesnt seem to work anyway, so theres no point
    # in switching from bash to zsh in this case
    enable = supportTerminal "urxvt";
    package = pkgs.rxvt-unicode-emoji;
    keybindings = {
      "Control-Alt-C" = "builtin-string:";
      "Control-Alt-V" = "builtin-string:";
    };
    extraConfig = {
      depth = 32;
      inheritPixmap = true;
    };
    scroll.bar.enable = false;
    fonts = [
      "xft:Noto Sans Mono:size=16"
      "xft:Symbols Nerd Font Mono:size=16"
    ];
  };
  programs.foot = {
    enable = supportTerminal "foot";
    server.enable = true;
    # https://codeberg.org/dnkl/foot/src/branch/master/foot.ini
    settings = {
      main = {
        font = "Noto Sans Mono:size=16,Noto Sans Mono CJK JP:size=16,Symbols Nerd Font Mono:size=16";
        dpi-aware = false;
        notify = "${pkgs.libnotify}/bin/notify-send -a \${app-id} -i \${app-id} \${title} \${body}";
        inherit shell;
      };
      url = {
        launch = "${pkgs.xdg-utils}/bin/xdg-open \${url}";
      };
      colors = {
        alpha = config.colors.alpha;
        background = config.colors.background;
        foreground = config.colors.foreground;
        regular0 = color 0;
        regular1 = color 1;
        regular2 = color 2;
        regular3 = color 3;
        regular4 = color 4;
        regular5 = color 5;
        regular6 = color 6;
        regular7 = color 7;
        bright0 = color 8;
        bright1 = color 9;
        bright2 = color 10;
        bright3 = color 11;
        bright4 = color 12;
        bright5 = color 13;
        bright6 = color 14;
        bright7 = color 15;
      };
    };
  };
  programs.kitty = {
    enable = supportTerminal "kitty";
    font.name = "Noto Sans Mono";
    font.size = 16;
    settings = {
      inherit shell;
      symbol_map = "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+FD46,U+F0000-U+FFFFF Symbols Nerd Font Mono";
      cursor = "none";
      open_url_with = "${pkgs.xdg-utils}/bin/xdg-open";
      focus_follows_mouse = true;
      repaint_delay = 4;
      foreground = hex config.colors.foreground;
      background = hex config.colors.background;
      background_opacity = builtins.toString config.colors.alpha;
      color0 = hex color 0;
      color1 = hex color 1;
      color2 = hex color 2;
      color3 = hex color 3;
      color4 = hex color 4;
      color5 = hex color 5;
      color6 = hex color 6;
      color7 = hex color 7;
      color8 = hex color 8;
      color9 = hex color 9;
      color10 = hex color 10;
      color11 = hex color 11;
      color12 = hex color 12;
      color13 = hex color 13;
      color14 = hex color 14;
      color15 = hex color 15;
      allow_remote_control = "socket";
      listen_on = "unix:/tmp/kitty";
      enabled_layouts = "all";
    };
  };
  xdg.configFile."fontconfig/conf.d/10-kitty-fonts.conf".text = lib.mkIf ((supportTerminal "kitty") && (config.programs.kitty.font.name == "Noto Sans Mono")) ''
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
<match target="scan">
    <test name="family">
        <string>Noto Sans Mono</string>
    </test>
    <edit name="spacing">
        <int>90</int>
    </edit>
</match>
</fontconfig>
  '';
}
