{ exec, ... }:
{
  secrets = exec [ "cat" "/secrets/nixos/default.nix" ] {
    # compress and base64 the file to make it representable in nix,
    # then decompress it back in a derivation (shouldn't there be a better way...)
    copyToStore =
      pkgs: name: path:
      let
        archive = exec [
          "${pkgs.buildPackages.bash}/bin/bash"
          "-c"
          ''
            cd /secrets/nixos
            echo '"'"$(
              ${pkgs.buildPackages.gnutar}/bin/tar -I ${pkgs.buildPackages.zstd}/bin/zstd --exclude-vcs \
                --transform='s#'${pkgs.lib.escapeShellArg path}'#!#' \
                -c -- ${pkgs.lib.escapeShellArg path} | base64 -w0
            )"'"'
          ''
        ];
      in
      derivation {
        __contentAddressed = true;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        preferLocalBuild = true;
        allowSubstitutes = false;
        allowedReferences = [ ];
        passAsFile = [ "archive" ];
        inherit name archive;
        inherit (pkgs.buildPackages) system;
        builder = "${pkgs.buildPackages.bash}/bin/bash";
        args = [
          "-c"
          ''
            ${pkgs.buildPackages.coreutils}/bin/base64 -d "$archivePath" |
              ${pkgs.buildPackages.gnutar}/bin/tar -P --transform="s#!#$out#" -I ${pkgs.buildPackages.zstd}/bin/zstd -x
          ''
        ];
      };
  };
}
