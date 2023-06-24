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
      url = "github:chayleaf/notlua";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notnft = {
      url = "github:chayleaf/notnft/f090546a7c190557c2081129b7e49a595f2ab76f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-router = {
      url = "github:chayleaf/nixos-router/5048633a6f38c6787cba1a010359ff5246ec532b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_11.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, impermanence, home-manager, nur, nix-gaming, notlua, notnft, nixos-mailserver, nixos-router, ... }:
  let
    # --impure required for developing
    # it takes the paths for notlua,notnft,nixos-router from filesystem as opposed to flake inputs
    developing = false;
    # IRL-related stuff I'd rather not put into git
    priv =
      if builtins.pathExists ./private.nix then (import ./private.nix { })
      else if builtins.pathExists ./private/default.nix then (import ./private { })
      # workaround for git flakes not having access to non-checked out files
      else if builtins?extraBuiltins.secrets then builtins.extraBuiltins.secrets
      # yes, this is impure, this is a last ditch effort at getting access to secrets
      else import /etc/nixos/private { };
    devPath = priv.devPath or ../.;
    # if x has key s, get it. Otherwise return def
    # All private config for hostname
    getPriv = hostname: priv.${hostname} or { };
    # Private NixOS config for hostname
    getPrivSys = hostname: (getPriv hostname).system or { };
    # Private home-manager config for hostname and username
    getPrivUser = hostname: user: (getPriv hostname).${user} or { };
    # extended lib
    lib = nixpkgs.lib // {
      quoteListenAddr = addr:
        if nixpkgs.lib.hasInfix ":" addr then "[${addr}]" else addr;
    };
    # can't use callPackage ./pkgs here, idk why; use import instead
    overlay = self: super: import ./pkgs {
      pkgs = super;
      pkgs' = self;
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
    # this is actual config, it gets processed below
    config = {
      nixserver = {
        modules = [
          nixos-mailserver.nixosModules.default
          ./system/devices/hp-probook-g0-server.nix
        ];
      };
      router-emmc = rec {
        system = "aarch64-linux";
        specialArgs.notnft = if developing then (import /${devPath}/notnft { inherit (nixpkgs) lib; }).config.notnft else notnft.lib.${system};
        specialArgs.router-lib = if developing then import /${devPath}/nixos-router/lib.nix { inherit (nixpkgs) lib; } else nixos-router.lib.${system};
        specialArgs.server-config = nixosConfigurations.nixserver.config;
        modules = [
          (import ./system/devices/bpi-r3-router.nix "emmc")
          (if developing then (import /${devPath}/nixos-router) else nixos-router.nixosModules.default)
        ];
      };
      router-sd = rec {
        system = "aarch64-linux";
        specialArgs.notnft = if developing then (import /${devPath}/notnft { inherit (nixpkgs) lib; }).config.notnft else notnft.lib.${system};
        specialArgs.router-lib = if developing then import /${devPath}/nixos-router/lib.nix { inherit (nixpkgs) lib; } else nixos-router.lib.${system};
        specialArgs.server-config = nixosConfigurations.nixserver.config;
        modules = [
          (import ./system/devices/bpi-r3-router.nix "sd")
          (if developing then (import /${devPath}/nixos-router) else nixos-router.nixosModules.default)
        ];
      };
      nixmsi = rec {
        system = "x86_64-linux";
        modules = [
          nix-gaming.nixosModules.pipewireLowLatency
          ./system/devices/msi-delta-15-workstation.nix
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

    # this is the system config processing part
    nixosConfigurations = builtins.mapAttrs (hostname: args @ { system ? "x86_64-linux", modules, specialArgs ? {}, nixpkgs ? {}, home ? {}, ... }:
      lib.nixosSystem ({
        inherit system;
        # allow modules to access nixpkgs directly, use customized lib,
        # and pass nixos-harware to let hardware modules import parts of nixos-hardware
        specialArgs = {
          inherit lib nixpkgs;
          hardware = nixos-hardware.nixosModules;
        } // specialArgs;
        modules = modules ++ [
          # Third-party NixOS modules
          impermanence.nixosModule 
          # My custom NixOS modules
          ./system/modules/vfio.nix
          ./system/modules/ccache.nix
          ./system/modules/impermanence.nix
          ./system/modules/common.nix
          (getPrivSys hostname)
          # The common configuration that isn't part of common.nix
          ({ config, pkgs, lib, ... }: {
            networking.hostName = lib.mkDefault hostname;
            nixpkgs.overlays = [ overlay ];
            nix.extraOptions = ''
              plugin-files = ${pkgs.nix-plugins.override { nix = config.nix.package; }}/lib/nix/plugins/libnix-extra-builtins.so
            '';

            # registry is used for the new flaky nix command
            nix.registry =
              builtins.mapAttrs
              (_: v: { flake = v; })
              (lib.filterAttrs (_: v: v?outputs) inputs);

            # add import'able flake inputs (like nixpkgs) to nix path
            # nix path is used for old nix commands (like nix-build, nix-shell)
            environment.etc = lib.mapAttrs'
              (name: value: {
                name = "nix/inputs/${name}";
                value = { source = value.outPath; };
              })
              (lib.filterAttrs (_: v: builtins.pathExists "${v}/default.nix") inputs);
            nix.nixPath = [ "/etc/nix/inputs" ];
          })
        ]
        # the following is NixOS home-manager module configuration. Currently unused, but I might start using it for some hosts later.
        ++ (lib.optionals (home != {} && ((home.common or {}).enableNixosModule or true)) [
          home-manager.nixosModules.home-manager
          {
            home-manager = builtins.removeAttrs (home.common or { }) [ "nixpkgs" "nix" "enableNixosModule" ];
          }
          {
            # set both to false to match behavior with standalone home-manager
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = false;
            home-manager.users = builtins.mapAttrs (username: modules: {
              imports = modules ++ [
                {
                  nixpkgs = (home.common or { }).nixpkgs or { };
                  nix = (home.common or { }).nix or { };
                }
                ({ config, pkgs, lib, ...}: {
                  nixpkgs.overlays = [ overlay ];
                  nix.package = lib.mkDefault pkgs.nixFlakes;
                  # this is only needed if nixos doesnt set plugin-files already
                  /*nix.extraOptions = ''
                    plugin-files = ${pkgs.nix-plugins.override { nix = config.nix.package; }}/lib/nix/plugins/libnix-extra-builtins.so
                  '';*/
                })
                (getPrivUser hostname username)
              ];
            }) (builtins.removeAttrs home [ "common" ]);
          }
        ]);
      } // (builtins.removeAttrs args [ "home" "modules" "nixpkgs" ])))
      config;
  in {
    inherit nixosConfigurations;
    overlays.default = overlay;
    packages = lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
    ] (system: let self = overlay self (import nixpkgs { inherit system; }); in self );
    nixosImages.router = let pkgs = import nixpkgs { system = "aarch64-linux"; overlays = [ overlay ]; }; in {
      emmcImage = pkgs.callPackage ./system/hardware/bpi_r3/image.nix {
        inherit (nixosConfigurations.router-emmc) config;
        rootfsImage = nixosConfigurations.router-emmc.config.system.build.rootfsImage;
        bpiR3Stuff = pkgs.bpiR3StuffEmmc;
      };
      sdImage = pkgs.callPackage ./system/hardware/bpi_r3/image.nix {
        inherit (nixosConfigurations.router-sd) config;
        rootfsImage = nixosConfigurations.router-sd.config.system.build.rootfsImage;
        bpiR3Stuff = pkgs.bpiR3StuffSd;
      };
    };

    # for each hostname, for each user, generate an attribute "${user}@${hostname}"
    homeConfigurations =
      builtins.foldl'
        (a: b: a // b)
        { }
        (builtins.concatLists
          (lib.mapAttrsToList
            (hostname: sysConfig:
            let
              system = if sysConfig?system then sysConfig.system else "x86_64-linux";
              common' = builtins.removeAttrs (sysConfig.home.common or { }) [ "nix" "nixpkgs" "enableNixosModule" ];
              pkgs = mkPkgs ({ inherit system; } // ((sysConfig.home.common or { }).nixpkgs or {}));
              common = common' // { inherit pkgs; };
            in 
              lib.mapAttrsToList
                # this is where actual config takes place
                (user: homeConfig: {
                  "${user}@${hostname}" = home-manager.lib.homeManagerConfiguration (common // {
                    modules = homeConfig ++ [
                      (getPrivUser hostname user)
                      ({ config, pkgs, lib, ... }: {
                        nixpkgs.overlays = [ overlay ];
                        nix.package = lib.mkDefault pkgs.nixFlakes;
                        # this is only needed if nixos doesnt set plugin-files already
                        /*nix.extraOptions = ''
                          plugin-files = ${pkgs.nix-plugins.override { nix = config.nix.package; }}/lib/nix/plugins/libnix-extra-builtins.so
                        '';*/
                      })
                    ];
                  });
                })
                (builtins.removeAttrs (sysConfig.home or { }) [ "common" ]))
            config));
  };
}
