{ exec, ... }: {
  secrets = exec [ "cat" "/etc/nixos/private/default.nix" ] {
    # compress and base64 the file to make it representable in nix,
    # then decompress it back in a derivation (shouldn't there be a better way...)
    copyToStore = pkgs: name: path:
      let
        archive = exec [ "${pkgs.bash}/bin/bash" "-c" ''
          cd /etc/nixos/private
          echo '"'"$(
            ${pkgs.gnutar}/bin/tar -I ${pkgs.zstd}/bin/zstd --exclude-vcs \
              --transform='s#'${pkgs.lib.escapeShellArg path}'#!#' \
              -c -- ${pkgs.lib.escapeShellArg path} | base64 -w0
          )"'"'
        '' ];
      in derivation {
        __contentAddressed = true;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        preferLocalBuild = true;
        allowSubstitutes = false;
        allowedReferences = [];
        passAsFile = [ "archive" ];
        inherit name archive;
        inherit (pkgs) system;
        builder = "${pkgs.bash}/bin/bash";
        args = [ "-c" ''
          ${pkgs.coreutils}/bin/base64 -d "$archivePath" |
            ${pkgs.gnutar}/bin/tar -P --transform="s#!#$out#" -I ${pkgs.zstd}/bin/zstd -x
        '' ];
      };
    };
}
