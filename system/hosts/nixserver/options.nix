{ lib
, ... }:
{
  options.server = with lib; mkOption {
    type = types.submodule {
      options = {
        domainName = mkOption {
          type = types.str;
          default = "pavluk.org";
          description = "domain name";
        };
        lanCidrV4 = mkOption {
          type = types.str;
          description = "LAN mask (IPv4)";
          example = "192.168.1.0/96";
          default = "0.0.0.0/0";
        };
        lanCidrV6 = mkOption {
          type = types.str;
          description = "LAN mask (IPv6)";
          example = "fd01:abcd::/64";
          default = "::/0";
        };
        localIpV4 = mkOption {
          type = with types; nullOr str;
          description = "server's local IPv4 address";
          example = "192.168.1.2";
          default = null;
        };
        localIpV6 = mkOption {
          type = with types; nullOr str;
          description = "server's local IPv6 address";
          example = "fd01:abcd::2";
          default = null;
        };
        noreplyPassword = mkOption {
          type = types.str;
          description = "noreply (only available via localhost) account password";
          default = "totallysafe";
        };
        hashedNoreplyPassword = mkOption {
          type = types.str;
          description = "hashed noreply password via mkpasswd -sm bcrypt";
        };
        unhashedNoreplyPassword = mkOption {
          type = types.str;
          description = "unhashed noreply password. \
              This should preferably be different from the password that is hashed for better security (yes, really)";
        };
        pizzabotMagic = mkOption {
          type = types.str;
          default = "<PIZZABOT_MAGIC_SEP>";
        };
      };
    };
    description = "server settings";
  };
}
