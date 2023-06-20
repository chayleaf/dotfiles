{ lib
, ... }:

{
  options.router-settings = {
    country_code = lib.mkOption {
      type = lib.types.str;
    };
    network = lib.mkOption {
      type = lib.types.str;
    };
    ssid = lib.mkOption {
      type = lib.types.str;
    };
    wpa_passphrase = lib.mkOption {
      type = lib.types.str;
    };
  };
}
