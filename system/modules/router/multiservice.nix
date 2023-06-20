{ lib
, pkgs
, config
, ... }:

let
  baseSystem = modules: lib.nixosSystem {
    inherit (pkgs) system;
    modules = [
      ({ lib, ... }: {
        networking = {
          firewall.enable = false;
          useDHCP = false;
        };
        system = {
          inherit (config.system) stateVersion;
        };
      })
    ] ++ modules;
  };
  baseServices = builtins.concatLists (map builtins.attrNames (baseSystem [ ]).options.systemd.services.definitions);
  baseEtc = builtins.concatLists (map builtins.attrNames (baseSystem [ ]).options.environment.etc.definitions);
  cfg = config.multiservice;
in
{
  options.multiservice = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        etc = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption {
              description = "Copy etc files";
            };
            options.fixup = lib.mkOption {
              default = lib.id;
              type = lib.types.function;
              description = lib.mdDoc "Function applied to each etc files (must return an attrset with `name` and `value`)";
            };
          };
        };
        services = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption {
              description = "Copy services";
            };
            options.fixup = lib.mkOption {
              default = lib.id;
              type = lib.types.function;
              description = "Function applied to each systemd service";
            };
          };
        };
        config = lib.mkOption {
          description = "nixpkgs instance's config";
          default = { };
          type = lib.types.attrs;
        };
      };
    });
  };
  config = lib.mkIf (cfg != { }) (lib.mkMerge (lib.mapAttrsToList (instName: instCfg:
  let
    result = baseSystem [ ({ ... }: instCfg.config) ];
  in {
    systemd.services = lib.mkIf instCfg.services.enable (lib.mkMerge (map
      (services: lib.mapAttrs' (name: value: {
        name = name + "-" + instName;
        value = instCfg.services.fixup name value;
      }) (builtins.removeAttrs services baseServices))
      result.options.systemd.services.definitions));
    environment.etc = lib.mkIf instCfg.etc.enable (lib.mkMerge
      (map
        (etc:
          lib.mapAttrs'
            (name: value: instCfg.etc.fixup { inherit name value; })
            (builtins.removeAttrs etc baseEtc))
        result.options.environment.etc.definitions));
  }) cfg));
}
