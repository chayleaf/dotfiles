{
  stdenv,
  replaceVars,
  fetchFromGitHub,
  mpv-unwrapped,
  port ? 8080,
  secondary ? false,
  ...
}:

stdenv.mkDerivation {
  pname = "subserv-mpv-plugin";
  version = "0.1";
  src = fetchFromGitHub {
    owner = "kaervin";
    repo = "subserv-mpv-plugin";
    rev = "08e312f02f3d3608d61944247d39148c34215f75";
    sha256 = "sha256-CXyp+AAgyocAEbhuMMPVDlAiocozPe8tm/dIUofCRL8=";
  };
  patches = [
    # patch for setting port and whether secondary subs should be shown
    # (also removes verbose logs)
    (replaceVars ./settings.patch {
      inherit port;
      sub_text = if secondary then "secondary-sub-text" else "sub-text";
    })
    # my custom changes
    ./custom.patch
  ];
  buildInputs = [ mpv-unwrapped ];
  installFlags = [ "SCRIPTS_DIR=$(out)/share/mpv/scripts" ];
  stripDebugList = [ "share/mpv/scripts" ];
  passthru.scriptName = "subserv.so";
  buildPhase = ''
    gcc -o subserv.so subserv.c -shared -fPIC
  '';
  installPhase = ''
    mkdir -p $out/share/mpv/scripts
    cp subserv.so $out/share/mpv/scripts
  '';
}
