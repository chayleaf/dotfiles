{ exec, ... }: {
  # I might get a somewhat better solution later, "enjoy" this for now
  secrets = let
    archive = exec [
      "sh" "-c"
      "echo '\"' && (cd /etc/nixos/private && tar czv . 2>/dev/null | base64 -w0) && echo '\"'"
    ];
  in pkgs: import (pkgs.stdenvNoCC.mkDerivation {
    name = "private";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out
      cd $out
      echo "${archive}" | base64 -d | tar xzv
    '';
    url = builtins.toFile "private.tar.gz" archive;
  });
}
