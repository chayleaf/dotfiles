{ lib, config, ... }:
with lib;
{
  options.minimal = mkOption {
    type = types.bool;
    default = false;
  };
  options.phone = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "whether this is a phone";
    };
    suspend = mkOption {
      type = types.bool;
      default = true;
    };
  };
  options.rustAnalyzerAndroidSettings = mkOption {
    type = with types; attrs;
    description = "Additional cargo arguments for rust-analyzer's RustAndroid command";
    # TODO: create a neovim plugin or edit an existing one for workspace-specific config
    default = {
      rust-analyzer = {
        cargo.target = "x86_64-linux-android";
      };
    };
  };
  options.wayland.windowManager.sway.vulkan = mkOption {
    type = types.bool;
    default = false;
    description = "set WLR_RENDERER to vulkan";
  };
  options.terminals = mkOption {
    type = with types; listOf str;
    description = "terminal kinds (possible values are alacritty, urxvt, kitty, foot)";
    default = [ "alacritty" ];
  };
  options.terminalBin = mkOption {
    type = types.str;
    description = "Path to terminal binary (output)";
  };
  options.terminalBinX = mkOption {
    type = types.str;
    description = "Path to terminal binary for X server (output)";
  };
  options.colors = {
    base = mkOption {
      type = with types; listOf str;
      description = "16 theme colors";
    };
    foreground = mkOption {
      type = types.str;
    };
    background = mkOption {
      type = types.str;
    };
    # 0-1
    alpha = mkOption {
      type = types.float;
      description = "opacity (0.0-1.0)";
    };
    hexAlpha = mkOption {
      type = types.str;
      description = "hex opacity (read-only)";
    };
    percentAlpha = mkOption {
      type = types.int;
      description = "opacity percentage (read-only)";
    };
    black = mkOption {
      type = types.str;
      description = "read-only";
    };
    red = mkOption {
      type = types.str;
      description = "read-only";
    };
    green = mkOption {
      type = types.str;
      description = "read-only";
    };
    yellow = mkOption {
      type = types.str;
      description = "read-only";
    };
    blue = mkOption {
      type = types.str;
      description = "read-only";
    };
    magenta = mkOption {
      type = types.str;
      description = "read-only";
    };
    cyan = mkOption {
      type = types.str;
      description = "read-only";
    };
    white = mkOption {
      type = types.str;
      description = "read-only";
    };
    brBlack = mkOption {
      type = types.str;
      description = "read-only";
    };
    brRed = mkOption {
      type = types.str;
      description = "read-only";
    };
    brGreen = mkOption {
      type = types.str;
      description = "read-only";
    };
    brYellow = mkOption {
      type = types.str;
      description = "read-only";
    };
    brBlue = mkOption {
      type = types.str;
      description = "read-only";
    };
    brMagenta = mkOption {
      type = types.str;
      description = "read-only";
    };
    brCyan = mkOption {
      type = types.str;
      description = "read-only";
    };
    brWhite = mkOption {
      type = types.str;
      description = "read-only";
    };
  };
  config.colors.hexAlpha =
    let
      hex = lib.trivial.toHexString (lib.trivial.min 255 (builtins.floor (config.colors.alpha * 256.0)));
    in
    if (builtins.stringLength hex) == 2 then hex else "0${hex}";
  config.colors.percentAlpha = builtins.floor (config.colors.alpha * 100.0);
  config.colors.black = builtins.elemAt config.colors.base 0;
  config.colors.red = builtins.elemAt config.colors.base 1;
  config.colors.green = builtins.elemAt config.colors.base 2;
  config.colors.yellow = builtins.elemAt config.colors.base 3;
  config.colors.blue = builtins.elemAt config.colors.base 4;
  config.colors.magenta = builtins.elemAt config.colors.base 5;
  config.colors.cyan = builtins.elemAt config.colors.base 6;
  config.colors.white = builtins.elemAt config.colors.base 7;
  config.colors.brBlack = builtins.elemAt config.colors.base 8;
  config.colors.brRed = builtins.elemAt config.colors.base 9;
  config.colors.brGreen = builtins.elemAt config.colors.base 10;
  config.colors.brYellow = builtins.elemAt config.colors.base 11;
  config.colors.brBlue = builtins.elemAt config.colors.base 12;
  config.colors.brMagenta = builtins.elemAt config.colors.base 13;
  config.colors.brCyan = builtins.elemAt config.colors.base 14;
  config.colors.brWhite = builtins.elemAt config.colors.base 15;
  options.termShell = {
    enable = mkOption {
      description = "Use a separate shell for gui terminal";
      type = types.bool;
      default = false;
    };
    path = mkOption {
      type = types.str;
    };
  };
}
