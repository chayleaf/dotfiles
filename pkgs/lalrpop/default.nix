{ lib
, rustPlatform
, rust
, fetchFromGitHub
, substituteAll
, stdenv
}:

rustPlatform.buildRustPackage rec {
  pname = "lalrpop";
  version = "0.19.9";

  src = fetchFromGitHub {
    owner = "lalrpop";
    repo = "lalrpop";
    rev = version;
    hash = "sha256-1jXLcIlyObo9eIg0q6CyUTGhcAyZ8TDGmxxYhVxgcS8=";
  };

  cargoHash = "sha256-o1zpkwBmU1f/BZ4RrWuF5YvgjLhQOBOEdSbmouLPKAo=";

  patches = [
    (substituteAll {
      src = ./use-correct-binary-path-in-tests.patch;
      target_triple = rust.toRustTarget stdenv.hostPlatform;
    })
  ];

  buildAndTestSubdir = "lalrpop";

  # there are some tests in lalrpop-test and some in lalrpop
  checkPhase = ''
    buildAndTestSubdir=lalrpop-test cargoCheckHook
    cargoCheckHook
  '';

  meta = with lib; {
    description = "LR(1) parser generator for Rust";
    homepage = "https://github.com/lalrpop/lalrpop";
    changelog = "https://github.com/lalrpop/lalrpop/blob/${src.rev}/RELEASES.md";
    license = with licenses; [ asl20 /* or */ mit ];
    maintainers = with maintainers; [ chayleaf ];
  };
}
