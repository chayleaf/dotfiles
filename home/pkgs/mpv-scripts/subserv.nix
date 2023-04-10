{ stdenv
, fetchFromGitHub
, mpv-unwrapped
, port ? 1337
, secondary ? false
, ... }:

stdenv.mkDerivation {
  pname = "subserv-mpv-plugin";
  version = "0.1";
  src = fetchFromGitHub {
    owner = "kaervin";
    repo = "subserv-mpv-plugin";
    rev = "08e312f02f3d3608d61944247d39148c34215f75";
    sha256 = "sha256-CXyp+AAgyocAEbhuMMPVDlAiocozPe8tm/dIUofCRL8=";
  };
  buildInputs = [ mpv-unwrapped ];
  installFlags = [ "SCRIPTS_DIR=$(out)/share/mpv/scripts" ];
  stripDebugList = [ "share/mpv/scripts" ];
  passthru.scriptName = "subserv.so";
  patchPhase = ''
    sed -i 's%<client.h>%<mpv/client.h>%' subserv.c
    sed -i 's%printf("Hello%// printf("Hello%' subserv.c
    sed -i 's%printf("Got event%// printf("Got event%' subserv.c
    sed -i 's/PORT 8080/PORT ${builtins.toString port}/' subserv.c
  '' + (if secondary then ''
    sed -i 's/sub-text/secondary-sub-text/g' subserv.c
  '' else "");
  buildPhase = ''
    gcc -o subserv.so subserv.c -shared -fPIC
  '';
  installPhase = ''
    mkdir -p $out/share/mpv/scripts
    cp subserv.so $out/share/mpv/scripts
  '';
}
