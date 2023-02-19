{ lib, ... }:
with lib; {
  options.terminals = mkOption {
    type = with types; listOf str;
    description = "terminal kinds (possible values are alacritty, urxvt, kitty, foot)";
    default = ["alacritty"];
  };
  options.terminalBin = mkOption {
    type = types.str;
    description = "Path to terminal binary (output)";
  };
  options.terminalBinX = mkOption {
    type = types.str;
    description = "Path to terminal binary for X server (output)";
  };
  options.colors = mkOption {
    type = types.submodule {
      options = {
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
      };
    };
  };
  options.termShell = mkOption {
    type = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        path = mkOption {
          type = types.str;
        };
      };
    };
    default = {enable=false;};
    description = "Use a separate shell for gui terminal";
  };
}
