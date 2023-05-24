{ python3
, fetchFromGitHub
, rustPlatform
, magic ? "<PIZZABOT_MAGIC_SEP>"
, ... }:

python3.pkgs.buildPythonPackage rec {
  pname = "pineapplebot";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "chayleaf";
    repo = "pizzabot_v3";
    rev = "master";
    sha256 = "sha256-ZLskMlllZfmqIlbSr0pNHHJehDycohiwqgYbuEYP7Qc=";
  };
  preBuild = ''
    head -n13 Cargo.toml > Cargo.toml.new
    mv Cargo.toml.new Cargo.toml
  '';
  sourceRoot = "source/pineapplebot";
  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit src sourceRoot;
    name = "${pname}-${version}";
    sha256 = "14jxgykwg1apy97gy1j8mz7ny2cqg4q9s03a2bk9kx2y6ibm4668";
  };
  nativeBuildInputs = with rustPlatform; [
    cargoSetupHook
    maturinBuildHook
  ];
  doCheck = false;
  doInstallCheck = true;
  pythonImportsCheck = [ "pineapplebot" ];
  PIZZABOT_MAGIC = magic;
}
