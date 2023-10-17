{ exec, ... }: {
  secrets = exec [ "cat" "/etc/nixos/private/default.nix" ] {
    # compress and base64 the file to make it representable in nix,
    # then decompress it back in a derivation (shouldn't there be a better way...)
    copyToStore = pkgs: name: path:
      let
        archive = exec [
          "/bin/sh" "-c"
          "echo '\"' && (cd /etc/nixos/private && tar -I ${pkgs.zstd}/bin/zstd -c -- ${pkgs.lib.escapeShellArg path} 2>/dev/null | base64 -w0) && echo '\"'"
        ];
      in "${pkgs.stdenvNoCC.mkDerivation {
        inherit name;
        unpackPhase = "true";
        buildPhase = "true";
        installPhase = ''
          mkdir -p $out
          cd $out
          echo "${archive}" | base64 -d | tar -I ${pkgs.zstd}/bin/zstd -x
        '';
      }}/${toString path}";
    };
}
