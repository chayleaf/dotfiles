{ lib, ... }:
{
  options.useAlacritty = lib.mkOption {
    type = with lib.types; uniq bool;
    description = "Use Alacritty";
    default = true;
  };
}
