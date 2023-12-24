{ lib
, stdenv
, fetchFromGitLab
}:

stdenv.mkDerivation rec {
  pname = "mobile-config-firefox";
  version = "4.2.0";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "mobile-config-firefox";
    rev = version;
    hash = "sha256-JEfgB+dqfy97n4FC2N6eHDV0aRFAhmFujYJHYa3kENE=";
  };

  makeFlags = [ "DESTDIR=$(out)" "FIREFOX_DIR=/lib/firefox" ];

  postInstall = ''
    rm -rf "$out/usr"
  '';

  meta = with lib; {
    description = "Mobile and privacy friendly configuration for Firefox (distro-independent";
    homepage = "https://gitlab.com/postmarketOS/mobile-config-firefox";
    license = licenses.mpl20;
    maintainers = with maintainers; [ chayleaf ];
    mainProgram = "mobile-config-firefox";
    platforms = platforms.all;
  };
}
