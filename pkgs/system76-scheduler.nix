{ lib
, fetchFromGitHub
, writeText
, rustPlatform
, pkg-config
, dbus
, bcc
}:

rustPlatform.buildRustPackage {
  pname = "system76-scheduler";
  version = "unstable-2022-11-08";
  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "system76-scheduler";
    rev = "0fe4d8dfc4275fd856aee28ca942b9fa53229fc9";
    sha256 = "sha256-uFFJkuMxqcGj6OQShF0zh/FGwX4/ln1l6NwGonkUsNI=";
  };
  cargoPatches = [(writeText "ron-rev.diff" ''
    diff --git i/daemon/Cargo.toml w/daemon/Cargo.toml
    index 0397788..fbd6202 100644
    --- i/daemon/Cargo.toml
    +++ w/daemon/Cargo.toml
    @@ -33,7 +33,7 @@ clap = { version = "3.1.18", features = ["cargo"] }
     # Necessary for deserialization of untagged enums in assignments.
     [dependencies.ron]
     git = "https://github.com/MomoLangenstein/ron"
    -branch = "253-untagged-enums"
    +rev = "afb960bb8b0402a79260533aa3b9d87a8abae72b"
     
     [dependencies.tracing-subscriber]
     version = "0.3.11"
    diff --git i/Cargo.lock w/Cargo.lock
    index a782756..fe56c1f 100644
    --- i/Cargo.lock
    +++ w/Cargo.lock
    @@ -788,7 +788,7 @@ dependencies = [
     [[package]]
     name = "ron"
     version = "0.8.0"
    -source = "git+https://github.com/MomoLangenstein/ron?branch=253-untagged-enums#afb960bb8b0402a79260533aa3b9d87a8abae72b"
    +source = "git+https://github.com/MomoLangenstein/ron?rev=afb960bb8b0402a79260533aa3b9d87a8abae72b#afb960bb8b0402a79260533aa3b9d87a8abae72b"
     dependencies = [
      "base64",
      "bitflags",
  '')];
  cargoSha256 = "sha256-tY7o09Nu1/Lbn//5+iecUmV67Aw1QvVLdUaD8DDgKi0=";
  cargoLock.lockFile = ./Cargo.lock;
  cargoLock.outputHashes."ron-0.8.0" = "sha256-k+LuTEq97/DohcsulXoLXWqFLzPUzIR1D5pGru+M5Ew=";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];
  EXECSNOOP_PATH = "${bcc}/bin/execsnoop";
  postInstall = ''
    install -D -m 0644 data/com.system76.Scheduler.conf $out/etc/dbus-1/system.d/com.system76.Scheduler.conf
    mkdir -p $out/etc/system76-scheduler
    install -D -m 0644 data/*.ron $out/etc/system76-scheduler/
  '';

  meta = {
    description = "System76 Scheduler";
    homepage = "https://github.com/pop-os/system76-scheduler";
    license = lib.licenses.mpl20;
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
