{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
in {
  security.acme.certs = lib.flip builtins.mapAttrs (lib.filterAttrs (k: v: v.enableACME) config.services.nginx.virtualHosts) (k: v: {
    postRun = let
      python = pkgs.python3.withPackages (p: with p; [ cryptography pyasn1 pyasn1-modules ]);
      tbs-hash = pkgs.writeScript "tbs-hash.py" ''
        #!${python}/bin/python3
        import hashlib
        from pyasn1.codec.der.decoder import decode
        from pyasn1.codec.der.encoder import encode
        from pyasn1_modules import rfc5280
        from cryptography import x509

        with open('full.pem', 'rb') as f: 
          cert = x509.load_pem_x509_certificate(f.read())
        tbs, _leftover = decode(cert.tbs_certificate_bytes, asn1Spec=rfc5280.TBSCertificate())
        precert_exts = [v.dotted_string for k, v in x509.ExtensionOID.__dict__.items() if k.startswith('PRECERT_')]
        exts = [ext for ext in tbs["extensions"] if str(ext["extnID"]) not in precert_exts]
        tbs["extensions"].clear()
        tbs["extensions"].extend(exts)
        print(hashlib.sha256(encode(tbs)).hexdigest())
      '';
    in ''
      ${tbs-hash} > "/var/lib/certspotter/tbs-hashes/${k}"
    '';
  });
  services.certspotter = {
    enable = true;
    extraFlags = [ ];
    watchlist = [ ".pavluk.org" ];
    hooks = lib.toList (pkgs.writeShellScript "certspotter-hook" ''
      if [[ "$EVENT" == discovered_cert ]]; then
        ${pkgs.gnugrep}/bin/grep -r "$TBS_SHA256" /var/lib/certspotter/tbs-hashes/ && exit
      fi
      (echo "Subject: $SUMMARY" && echo && cat "$TEXT_FILENAME") | /run/wrappers/bin/sendmail -i webmaster-certspotter@${cfg.domainName}
    '');
  };
}
