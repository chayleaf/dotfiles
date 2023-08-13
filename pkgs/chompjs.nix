# TODO: remove this file when searxng gets updated in nixpkgs
{ lib
, buildPythonPackage
, fetchPypi
}:

buildPythonPackage rec {
  pname = "chompjs";
  version = "1.2.2";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-I5PbVinyjO1OF78t9h67lVBM/VsogYoMj3iFZS4WTn8=";
  };

  pythonImportsCheck = [ "chompjs" ];

  meta = with lib; {
    description = "Parsing JavaScript objects into Python dictionaries";
    homepage = "https://pypi.org/project/chompjs/";
    license = licenses.mit;
    maintainers = with maintainers; [ chayleaf ];
  };
}
