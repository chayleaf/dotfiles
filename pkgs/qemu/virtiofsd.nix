{
  stdenv,
  libseccomp,
  libcap_ng,
  buildPackages,
  meson,
  ninja,
  pkg-config,
  perl,
  glib,
  pixman,
  qemu,
  python3Packages,
}:

qemu.overrideAttrs (old: {
  pname = "qemu-virtiofsd";

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    perl
    python3Packages.python
  ];

  buildInputs = [
    glib
    libseccomp
    libcap_ng
    pixman
  ];

  # overly defensive flags
  configureFlags = [
    "--disable-strip"
    "--disable-docs"
    "--disable-gettext"
    "--disable-sparse"
    "--disable-guest-agent"
    "--disable-guest-agent-msi"
    "--disable-qga-vss"
    "--disable-hax"
    "--disable-whpx"
    "--disable-hvf"
    "--disable-nvmm"
    "--disable-xen"
    "--disable-vfio-user-server"
    "--disable-dbus-display"
    "--enable-tools"
    "--enable-virtiofsd"
    "--localstatedir=/var"
    "--sysconfdir=/etc"
    "--meson=meson"
    "--cross-prefix=${stdenv.cc.targetPrefix}"
    "--enable-seccomp"
    "--disable-tcg"
    "--disable-kvm"
    "--disable-gio"
    "--disable-cfi"
    "--disable-tpm"
    "--disable-keyring"
    "--disable-spice"
    "--disable-spice-protocol"
    "--disable-u2f"
    "--disable-netmap"
    "--disable-vde"
    "--disable-vmnet"
    "--disable-vnc"
    "--disable-vhost-kernel"
    "--disable-vhost-net"
    "--disable-vhost-crypto"
    "--disable-vhost-user-blk-server"
    "--disable-virtfs"
    "--disable-bochs"
    "--disable-cloop"
    "--disable-dmg"
    "--disable-qcow1"
    "--disable-vdi"
    "--disable-vvfat"
    "--disable-qed"
    "--disable-parallels"
  ];

  postFixup = "";
  doCheck = false;
  postInstall = ''
    rm $out/bin/*
    mv $out/libexec/virtiofsd $out/bin
    rm -rf $out/libexec $out/share
  '';

  outputs = [ "out" ];
})
