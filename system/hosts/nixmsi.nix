{ lib
, pkgs
, config
, inputs
, ... }:

/*
  # for old kernel versions
  zenKernels = pkgs.callPackage "${pkgs.path}/pkgs/os-specific/linux/kernel/zen-kernels.nix";
  zenKernel = (version: sha256: (zenKernels {
    kernelPatches = [
      pkgs.linuxKernel.kernelPatches.bridge_stp_helper
      pkgs.linuxKernel.kernelPatches.request_key_helper
    ];
    argsOverride = {
      src = pkgs.fetchFromGitHub {
        owner = "zen-kernel";
        repo = "zen-kernel";
        rev = "v${version}-zen1";
        inherit sha256;
      };
      inherit version;
      modDirVersion = lib.versions.pad 3 "${version}-zen1";
    };
  }).zen);
  zenKernelPackages = version: sha256: pkgs.linuxPackagesFor (zenKernel version sha256);
*/

{
  imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

  system.stateVersion = "22.11";

  ### SECTION 1: HARDWARE/BOOT PARAMETERS ###

  boot = {
    kernel.sysctl = {
      "vm.dirty_ratio" = 4;
      "vm.dirty_background_ratio" = 2;
      "vm.swappiness" = 40;
    };
    # TODO: uncomment when iwlwifi gets fixed, whenever that will be (broken in 6.5.5)
    # kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    /*kernelPackages = zenKernelPackages "6.1.9" "0fsmcjsawxr32fxhpp6sgwfwwj8kqymy0rc6vh4qli42fqmwdjgv";*/
  };

  # for testing different zen kernel versions:
  # specialisation = {
  #   zen619.configuration.boot.kernelPackages = zenKernelPackages "6.1.9" "0fsmcjsawxr32fxhpp6sgwfwwj8kqymy0rc6vh4qli42fqmwdjgv";
  # };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam-original"
  ];
  hardware = {
    steam-hardware.enable = true;
    opengl.driSupport32Bit = true;
    # needed for sway WLR_RENDERER=vulkan
    opengl.extraPackages = with pkgs; [ vulkan-validation-layers ];
  };

  # see modules/vfio.nix
  vfio.enable = true;
  vfio.libvirtdGroup = [ config.common.mainUsername ];
  
  # because libvirtd's nat is broken for some reason...
  networking.nat = {
    enable = true;
    internalInterfaces = [ "virbr0" ];
    externalInterface = "enp7s0f4u1c2";
  };

  ### SECTION 2: SYSTEM CONFIG/ENVIRONMENT ###

  networking.useDHCP = true;
  # networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [
    27015
    25565
    7777
    9887
  ];
  # kde connect
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.wireless.iwd.enable = true;

  services.ratbagd.enable = true;

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;

  # System76 scheduler (not actually a scheduler, just a renice daemon) for improved responsiveness
  /*services.dbus.packages = [ pkgs.system76-scheduler ];
  systemd.services.system76-scheduler = {
    description = "Automatically configure CPU scheduler for responsiveness on AC";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "dbus";
      BusName= "com.system76.Scheduler";
      ExecStart = "${pkgs.system76-scheduler}/bin/system76-scheduler daemon";
      ExecReload = "${pkgs.system76-scheduler}/bin/system76-scheduler daemon reload";
    };
  };
  environment.etc."system76-scheduler/assignments.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/assignments.ron";
  environment.etc."system76-scheduler/config.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/config.ron";
  environment.etc."system76-scheduler/exceptions.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/exceptions.ron";*/
  services.system76-scheduler.enable = true;
  services.system76-scheduler.assignments = {
    games.matchers = [ "osu!" ];
  };

  common.minimal = false;
  common.gettyAutologin = true;
  # programs.firejail.enable = true;
  # doesn't work:
  # programs.wireshark.enable = true;
  # users.groups.wireshark.members = [ config.common.mainUsername ];
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  # from nix-gaming
  services.pipewire.lowLatency = {
    enable = false;
    # 96 is mostly fine but has some xruns
    # 128 has xruns every now and then too
    quantum = 128;
    rate = 48000;
  };

  programs.sway.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
  };

  programs.ccache.enable = true;
  services.sshd.enable = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  users.users.hydra-builder = {
    uid = 1001;
    isNormalUser = true;
  };
  nix.settings = {
    netrc-file = "/secrets/netrc";
    trusted-users = [ "hydra-builder" ];
    substituters = [
      "https://binarycache.pavluk.org"
      "https://cache.nixos.org/"
    ];
    trusted-substituters = [
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    trusted-public-keys = [
      "binarycache.pavluk.org:Vk0ms/vSqoOV2JXeNVOroc8EfilgVxCCUtpCShGIKsQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];
  };
  services.udev.packages = [
    pkgs.android-udev-rules
  ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  environment.systemPackages = with pkgs; [
    comma
    neovim
    man-pages man-pages-posix
  ];
  documentation.dev.enable = true;

  impermanence.directories = [
    /secrets
  ];
}
