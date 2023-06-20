{ lib
, config
, ... }:

let
  cfg = config.router;
in {
  services.avahi.enable = lib.mkDefault true;
  services.avahi.publish.enable = lib.mkDefault true;
  services.avahi.allowInterfaces = lib.mkDefault (builtins.attrNames cfg.interfaces);
}
