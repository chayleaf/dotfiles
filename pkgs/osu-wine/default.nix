## Configuration:
# Control you default wine config in nixpkgs-config:
# wine = {
#   release = "stable"; # "stable", "unstable", "staging", "wayland"
#   build = "wineWow"; # "wine32", "wine64", "wineWow"
# };
# Make additional configurations on demand:
# wine.override { wineBuild = "wine32"; wineRelease = "staging"; };
{ lib, stdenv, callPackage, darwin,
  wineBuild ? if stdenv.hostPlatform.system == "x86_64-linux" then "wineWow" else "wine32",
  gettextSupport ? true,
  fontconfigSupport ? stdenv.isLinux,
  alsaSupport ? stdenv.isLinux,
  gtkSupport ? false,
  openglSupport ? true,
  tlsSupport ? true,
  gstreamerSupport ? false,
  cupsSupport ? true,
  dbusSupport ? stdenv.isLinux,
  openclSupport ? false,
  cairoSupport ? stdenv.isLinux,
  odbcSupport ? false,
  netapiSupport ? false,
  cursesSupport ? true,
  vaSupport ? false,
  pcapSupport ? false,
  v4lSupport ? false,
  saneSupport ? stdenv.isLinux,
  gphoto2Support ? false,
  krb5Support ? false,
  pulseaudioSupport ? stdenv.isLinux,
  udevSupport ? stdenv.isLinux,
  xineramaSupport ? stdenv.isLinux,
  vulkanSupport ? true,
  sdlSupport ? true,
  usbSupport ? true,
  mingwSupport ? true,
  waylandSupport ? stdenv.isLinux,
  x11Support ? stdenv.isLinux,
  embedInstallers ? false, # The Mono and Gecko MSI installers
  moltenvk ? darwin.moltenvk # Allow users to override MoltenVK easily
}:

let wine-build = build: release:
      lib.getAttr build (callPackage ./packages.nix {
        wineRelease = release;
        supportFlags = {
          inherit
            alsaSupport cairoSupport cupsSupport cursesSupport dbusSupport
            embedInstallers fontconfigSupport gettextSupport gphoto2Support
            gstreamerSupport gtkSupport krb5Support mingwSupport netapiSupport
            odbcSupport openclSupport openglSupport pcapSupport
            pulseaudioSupport saneSupport sdlSupport tlsSupport udevSupport
            usbSupport v4lSupport vaSupport vulkanSupport waylandSupport
            x11Support xineramaSupport
          ;
        };
        inherit moltenvk;
      });

in
  callPackage ./osu-wine.nix {
    wineUnstable = wine-build wineBuild "unstable";
  }
