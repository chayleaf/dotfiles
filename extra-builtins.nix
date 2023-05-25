{ exec, ... }: {
  secrets = exec [ "cat" "/etc/nixos/private/default.nix" ] {
    # compress and base64 the file to make it representable in nix,
    # then decompress it back in a derivation (shouldn't there be a better way...)
    copyToStore = pkgs: path:
      let
        archive = exec [
          "sh" "-c"
          "echo '\"' && (cd /etc/nixos/private && tar czv ${path} 2>/dev/null | base64 -w0) && echo '\"'"
        ];
      in "${pkgs.stdenvNoCC.mkDerivation {
        name = "private";
        unpackPhase = "true";
        buildPhase = "true";
        installPhase = ''
          mkdir -p $out
          cd $out
          echo "${archive}" | base64 -d | tar xzv
        '';
        url = builtins.toFile "private.tar.gz.base64" archive;
      }}/${path}";
    };
}
