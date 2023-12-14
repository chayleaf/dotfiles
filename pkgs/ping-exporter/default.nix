{ lib
, fetchFromGitHub
, rustPlatform
}:

rustPlatform.buildRustPackage rec {
  pname = "ping-exporter";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "chayleaf";
    repo = "ping-exporter";
    rev = "cf5e5f7e96fb477e015d44cd462fb996b944c896";
    hash = "sha256-eZncfKTegLp+KBnAds8YR7ZMN8i7jDIIN8qt7832+0Y=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = with lib; {
    description = "A ping exporter for Prometheus";
    license = with lib.licenses; [ mit asl20 ];
    maintainers = with lib.maintainers; [ chayleaf ];
  };
}
