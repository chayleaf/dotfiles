{
  description = "NixOS + Home Manager configuration of chayleaf";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/3dc2b4f8166f744c3b3e9ff8224e7c5d74a5424f";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:chayleaf/nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    mobile-nixos = {
      # url = "github:NixOS/mobile-nixos";
      url = "github:chayleaf/mobile-nixos/fix-op6-modem";
      flake = false;
    };
    impermanence.url = "github:nix-community/impermanence";
    nur.url = "github:nix-community/NUR";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    coop-ofd = {
      url = "github:chayleaf/coop-ofd";
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
      url = "github:chayleaf/notlua";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notnft = {
      url = "github:chayleaf/notnft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-router = {
      url = "github:chayleaf/nixos-router";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    maubot = {
      url = "github:chayleaf/maubot.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      # prevent extra input from being in flake.lock
      # (this doesn't affect any behavior)
      inputs.nixpkgs-22_11.follows = "nixpkgs";
      inputs.nixpkgs-23_05.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = base-inputs@{ self, nixpkgs, ... }:
  let
    # --impure required for developing
    # it takes the paths for modules from filesystem as opposed to flake inputs
    dev = {
      # coop-ofd = true;
      # maubot = true;
      # mobile-nixos = true;
      # nixos-router = true;
      # notnft = true;
    };
    # IRL-related stuff I'd rather not put into git
    priv =
      if builtins.pathExists ./private.nix then import ./private.nix { }
      else if builtins.pathExists ./private/default.nix then import ./private { }
      # workaround for git flakes not having access to non-checked out files
      else if builtins?extraBuiltins.secrets then builtins.extraBuiltins.secrets
      # yes, this is impure, this is a last ditch effort at getting access to secrets
      else import /etc/nixos/private { };
    devPath = priv.devPath or ../.;
    inputs = builtins.mapAttrs
      (name: input:
        if dev.${name} or false then
          (if input._type or null == "flake"
          then (import base-inputs.flake-compat { src = /${devPath}/${name}; }).defaultNix
          else /${devPath}/${name})
          else input)
      base-inputs;
    # if x has key s, get it. Otherwise return def
    # All private config for hostname
    getPriv = hostname: priv.${hostname} or { };
    # Private NixOS config for hostname
    getPrivSys = hostname: (getPriv hostname).system or { };
    # Private home-manager config for hostname and username
    getPrivUser = hostname: user: (getPriv hostname).${user} or { };
    # extended lib
    lib = nixpkgs.lib // import ./lib.nix { inherit (nixpkgs) lib; };
    # can't use callPackage ./pkgs here, idk why; use import instead
    overlay' = args: self: super: import ./pkgs ({
      pkgs = super;
      pkgs' = self;
      lib = super.lib;
      inherit inputs;
    } // args);
    overlay = overlay' { };
    # I override some settings down the line, but overlays always stay the same
    mkPkgs = config: import nixpkgs (config // {
      overlays = config.overlays or [ ] ++ [ overlay ];
    });
    # this is actual config, it gets processed below
    config = let
      mkBpiR3 = args: config: config // {
        system = "aarch64-linux";
        modules = config.modules or [ ] ++ [ (import ./system/devices/bpi-r3-router.nix args) ];
      };
      routerConfig = rec {
        system = "aarch64-linux";
        modules = [
          {
            _module.args.server-config = self.nixosConfigurations.server.config;
            _module.args.notnft = inputs.notnft.lib.${system};
          }
          inputs.nixos-router.nixosModules.default
        ];
      };
    in {
      router-emmc = mkBpiR3 "emmc" routerConfig;
      router-sd = mkBpiR3 "sd" routerConfig;
      server = {
        system = "aarch64-linux";
        modules = [
          { _module.args.router-config = self.nixosConfigurations.router-emmc.config; }
          ./system/devices/radxa-rock5a-server.nix
        ];
      };
      nixmsi = rec {
        system = "x86_64-linux";
        modules = [ ./system/devices/msi-delta-15-workstation.nix ];
        home.common.extraSpecialArgs = {
          notlua = inputs.notlua.lib.${system};
        };
        home.user = [ ./home/hosts/nixmsi.nix ];
      };
      phone = rec {
        system = "aarch64-linux";
        modules = [ ./system/devices/oneplus-6-phone.nix ];
        home.common.extraSpecialArgs = {
          notlua = inputs.notlua.lib.${system};
        };
        home.user = [ ./home/hosts/phone.nix ];
      };
    };

  in {
    overlays.default = overlay;
    packages = lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
    ] (system: let self = overlay' { isOverlay = false; } (mkPkgs { inherit system; } // self) (import nixpkgs { inherit system; }); in self);
    nixosImages.router = let pkgs = mkPkgs { inherit (config.router-emmc) system; }; in {
      emmcImage = pkgs.callPackage ./system/hardware/bpi-r3/image.nix {
        inherit (self.nixosConfigurations.router-emmc) config;
        rootfsImage = self.nixosConfigurations.router-emmc.config.system.build.rootfsImage;
        bpiR3Stuff = pkgs.bpiR3StuffEmmc;
      };
      sdImage = pkgs.callPackage ./system/hardware/bpi-r3/image.nix {
        inherit (self.nixosConfigurations.router-sd) config;
        rootfsImage = self.nixosConfigurations.router-sd.config.system.build.rootfsImage;
        bpiR3Stuff = pkgs.bpiR3StuffSd;
      };
    };

    hydraJobs = {
      server.${config.server.system} = self.nixosConfigurations.server.config.system.build.toplevel;
      router.${config.router-emmc.system} = self.nixosConfigurations.router-emmc.config.system.build.toplevel;
      phone.${config.phone.system} = self.nixosConfigurations.phone.config.system.build.toplevel;
      phone-home.${config.phone.system} = self.homeConfigurations."user@phone".activation-script;
      workstation.${config.nixmsi.system} = self.nixosConfigurations.nixmsi.config.system.build.toplevel;
      workstation-home.${config.nixmsi.system} = self.homeConfigurations."user@nixmsi".activation-script;
    };

    # this is the system config processing part
    nixosConfigurations = lib.flip builtins.mapAttrs config (hostname: args @ { modules, nixpkgs ? {}, home ? {}, ... }:
      lib.nixosSystem {
        inherit (args) system;
        # allow modules to access nixpkgs directly, use customized lib,
        # and pass nixos-harware to let hardware modules import parts of nixos-hardware
        specialArgs = {
          inherit inputs lib;
          hardware = inputs.nixos-hardware.nixosModules;
        } // args.specialArgs or { };
        modules = args.modules or [ ]
        ++ [
          (getPrivSys hostname)
          { networking.hostName = lib.mkDefault hostname;
            nixpkgs.overlays = [ overlay ]; }
          inputs.impermanence.nixosModule 
        ]
        ++ map (x: ./system/modules/${x}) (builtins.attrNames (builtins.readDir ./system/modules))
        # the following is NixOS home-manager module configuration. Currently unused, but I might start using it for some hosts later.
        ++ lib.optionals (home != { } && home.common.enableNixosModule or false) [
          inputs.home-manager.nixosModules.home-manager
          { home-manager = builtins.removeAttrs (home.common or { }) [ "nixpkgs" "nix" "enableNixosModule" ]; }
          { # set both to false to match behavior with standalone home-manager
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = false;
            home-manager.users = builtins.mapAttrs (username: modules: {
              imports = modules ++ [
                { nixpkgs = home.common.nixpkgs or { };
                  nix = home.common.nix or { }; }
                ({ config, pkgs, lib, ...}: {
                  nixpkgs.overlays = [ overlay ];
                  nix.package = lib.mkDefault pkgs.nixForNixPlugins; })
                (getPrivUser hostname username)
              ];
            }) (builtins.removeAttrs home [ "common" ]); }
        ];
      });

    # for each hostname, for each user, generate an attribute "${user}@${hostname}"
    homeConfigurations =
      builtins.listToAttrs (builtins.concatLists
        (lib.flip lib.mapAttrsToList config
          (hostname: { system, home ? {}, ... }:
          let
            common' = builtins.removeAttrs (home.common or { }) [ "nix" "nixpkgs" "enableNixosModule" ];
            pkgs = mkPkgs ({ inherit system; } // home.common.nixpkgs or { });
            common = common' // { inherit pkgs; };
          in 
            lib.flip lib.mapAttrsToList (builtins.removeAttrs home [ "common" ])
              # this is where actual config takes place
              (user: homeConfig: lib.nameValuePair "${user}@${hostname}" 
              (inputs.home-manager.lib.homeManagerConfiguration (common // {
                extraSpecialArgs = (common.extraSpecialArgs or { }) // { inherit inputs; };
                modules =
                  homeConfig
                  ++ common.modules or [ ]
                  ++ [
                    (getPrivUser hostname user)
                    ({ pkgs, lib, ... }: {
                      nixpkgs.overlays = [ overlay ];
                      nix.package = lib.mkDefault pkgs.nixForNixPlugins;
                    })
                  ];
              }))))));
  };
}
