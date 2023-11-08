{ lib
, stdenv
, fetchFromGitHub
, cmake

, fontconfig
, freetype
}:

stdenv.mkDerivation rec {
  pname = "libaribcaption";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "xqq";
    repo = "libaribcaption";
    rev = "v${version}";
    hash = "sha256-x6l0ZrTktSsqfDLVRXpQtUOruhfc8RF3yT991UVZiKA=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [ "-DBUILD_SHARED_LIBS=ON" ];

  buildInputs = lib.optionals (!stdenv.isDarwin) [ fontconfig freetype ];

  meta = with lib; {
    description = "Portable ARIB STD-B24 Caption Decoder/Renderer";
    homepage = "https://github.com/xqq/libaribcaption";
    license = licenses.mit;
    maintainers = with maintainers; [ chayleaf ];
  };
}
