{
  description = "NixOS + Home Manager configuration of chayleaf";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    nur.url = "github:nix-community/NUR";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notlua = {
      url = "github:chayleaf/notlua/469652092f4f2e951b0db29027b05346b32d8122";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_11.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, impermanence, home-manager, nur, nix-gaming, notlua, nixos-mailserver, ... }:
  let
    # IRL-related stuff I'd rather not put into git
    priv =
      if builtins.pathExists ./private.nix then (import ./private.nix)
      else if builtins.pathExists ./private/default.nix then (import ./private)
      else { };
    # if x has key s, get it. Otherwise return def
    getOr = def: s: x: with builtins; if hasAttr s x then getAttr s x else def;
    # All private config for hostname
    getPriv = hostname: getOr { } hostname priv;
    # Private NixOS config for hostname
    getPrivSys = hostname: getOr { } "system" (getPriv hostname);
    # Private home-manager config for hostname and username
    getPrivUser = hostname: user: getOr { } user (getPriv hostname);
    # extended lib
    lib = nixpkgs.lib // {
      quoteListenAddr = addr:
        if nixpkgs.lib.hasInfix ":" addr then "[${addr}]" else addr;
    };
    # can't use callPackage here, idk why; use import instead
    overlay = self: super: import ./pkgs {
      pkgs = super;
      lib = super.lib;
      nur = import nur {
        pkgs = super;
        nurpkgs = super;
      };
      nix-gaming = nix-gaming.packages.${super.system};
    };
    # I override some settings down the line, but overlays always stay the same
    mkPkgs = config: import nixpkgs (config // {
      overlays = (if config?overlays then config.overlays else [ ]) ++ [ overlay ];
    });
    # this is actual config, it gets processed later
    config = {
      nixserver = {
        modules = [
          nixos-mailserver.nixosModules.default
          ./system/hardware/hp_probook_g0.nix
          ./system/hosts/nixserver
        ];
      };
      router = {
        system = "aarch64-linux";
        modules = [
          ./system/hardware/bpi_r3.nix
          ./system/hosts/router
        ];
      };
      nixmsi = rec {
        system = "x86_64-linux";
        modules = [
          nix-gaming.nixosModules.pipewireLowLatency
          ./system/hardware/msi_delta_15.nix
          ./system/hosts/nixmsi.nix
        ];
        home.common.enableNixosModule = false;
        home.common.extraSpecialArgs = {
          notlua = notlua.lib.${system};
        };
        home.user = [
          nur.nixosModules.nur
          ./home/hosts/nixmsi.nix
        ];
      };
    };
  in {
    overlays.default = overlay;
    packages = lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
    ] (system: let self = overlay self (import nixpkgs { inherit system; }); in self );
    # this is the system config part
    nixosConfigurations = builtins.mapAttrs (hostname: args @ { system ? "x86_64-linux", modules, nixpkgs ? {}, home ? {}, ... }:
      lib.nixosSystem ({
        inherit system;
        modules = modules ++ [
          { networking.hostName = hostname; }
          ./system/modules/vfio.nix
          ./system/modules/ccache.nix
          ./system/modules/impermanence.nix
          ./system/modules/common.nix
          impermanence.nixosModule 
          (getPrivSys hostname)
          {
            nixpkgs.overlays = [ overlay ];

            nix.registry =
              builtins.mapAttrs
              (_: v: { flake = v; })
              (lib.filterAttrs (_: v: v?outputs) inputs);

            # add import'able flakes (like nixpkgs) to nix path
            environment.etc = lib.mapAttrs'
              (name: value: {
                name = "nix/inputs/${name}";
                value = { source = value.outPath; };
              })
              (lib.filterAttrs (_: v: builtins.pathExists "${v}/default.nix") inputs);
            nix.nixPath = [ "/etc/nix/inputs" ];
          }
        ] ++ (lib.optionals (home != {} && (getOr true "enableNixosModule" (getOr {} "common" home))) [
          # only use NixOS HM module if same nixpkgs as system nixpkgs is used for user
          # why? because it seems that HM lacks the option to override pkgs, only change nixpkgs.* settings
          home-manager.nixosModules.home-manager
          {
            home-manager = builtins.removeAttrs (getOr { } "common" home) [ "nixpkgs" "nix" "enableNixosModule" ];
          }
          {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = false;
            home-manager.users = builtins.mapAttrs (username: modules: {
              imports = modules ++ [
                {
                  nixpkgs = getOr { } "nixpkgs" (getOr { } "common" home);
                  nix = getOr { } "nix" (getOr { } "common" home);
                }
                ({ pkgs, ...}: {
                  nixpkgs.overlays = [ overlay ];
                })
                (getPrivUser hostname username)
              ];
            }) (builtins.removeAttrs home [ "common" ]);
          }
        ]);
        specialArgs = {
          inherit lib nixpkgs;
          hardware = nixos-hardware.nixosModules;
        };
      } // (builtins.removeAttrs args [ "home" "modules" "nixpkgs" ])))
      config;
    # for each hostname, for each user, generate an attribute "${user}@${hostname}"
    homeConfigurations =
      builtins.foldl'
        (a: b: a // b)
        { }
        (builtins.concatLists
          (lib.mapAttrsToList
            (hostname: sysConfig:
            let
              common = builtins.removeAttrs (getOr { } "common" sysConfig.home) [ "nixpkgs" "enableNixosModule" ];
              pkgs = getOr (mkPkgs { system = if sysConfig?system then sysConfig.system else "x86_64-linux"; }) "pkgs" common;
              common' = common // { inherit pkgs; };
            in 
              lib.mapAttrsToList
                # this is where actual config takes place
                (user: homeConfig: {
                  "${user}@${hostname}" = home-manager.lib.homeManagerConfiguration (common' // {
                    modules = homeConfig ++ [
                      (getPrivUser hostname user)
                      ({ pkgs, ... }: {
                        nixpkgs.overlays = [ overlay ];
                        nix.package = pkgs.nixFlakes;
                      })
                    ];
                  });
                })
                (builtins.removeAttrs (getOr { } "home" sysConfig) [ "common" ]))
            config));
  };
}
