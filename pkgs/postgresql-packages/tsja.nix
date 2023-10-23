{ lib
, stdenv
, postgresql
, mecab
}:

stdenv.mkDerivation rec {
  pname = "tsja";
  version = "0.5.0";

  src = fetchTarball {
    url = "https://www.amris.jp/tsja/tsja-${version}.tar.xz";
    sha256 = "0hx4iygnqw1ay3nwrf3x2izflw4ip9i8i0yny26vivdz862m97w7";
  };

  postPatch = ''
    substituteInPlace Makefile \
      --replace /usr/local/pgsql ${postgresql} \
      --replace -L/usr/local/lib "" \
      --replace -I/usr/local/include ""
    substituteInPlace tsja.c --replace /usr/local/lib/mecab ${mecab}/lib/mecab
  '';

  buildInputs = [ postgresql mecab ];

  installPhase = ''
    mkdir -p $out/lib $out/share/postgresql/extension
    cp libtsja.so $out/lib
    cp dbinit_libtsja.txt $out/share/postgresql/extension/libtsja_dbinit.sql
  '';

  meta = with lib; {
    description = "PostgreSQL extension implementing Japanese text search";
    homepage = "https://www.amris.jp/tsja/index.html";
    maintainers = with maintainers; [ chayleaf ];
    platforms = postgresql.meta.platforms;
    license = licenses.postgresql;
  };
}
