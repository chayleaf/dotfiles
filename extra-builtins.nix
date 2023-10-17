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
        inherit name;
        inherit (pkgs) system;
        builder = "${pkgs.bash}/bin/bash";
        args = [ "-c" ''
          echo '${archive}' | ${pkgs.coreutils}/bin/base64 -d |
            ${pkgs.gnutar}/bin/tar -P --transform="s#!#$out#" -I ${pkgs.zstd}/bin/zstd -x
        '' ];
      };
    };
}
