{ lib
, buildGoModule
, fetchFromGitHub
, lowdown
}:

buildGoModule rec {
  pname = "certspotter";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "SSLMate";
    repo = "certspotter";
    rev = "v${version}";
    hash = "sha256-0+7GWxbV4j2vVdmool8J9hqRqUi8O/yKedCyynWJDkE=";
  };

  vendorHash = "sha256-haYmWc2FWZNFwMhmSy3DAtj9oW5G82dX0fxpGqI8Hbw=";

  patches = [ ./configurable-sendmail.patch ];

  ldflags = [ "-s" "-w" ];

  nativeBuildInputs = [ lowdown ];

  postInstall = ''
    cd man
    make
    mkdir -p $out/share/man/man8
    mv *.8 $out/share/man/man8
  '';

  meta = with lib; {
    description = "Certificate Transparency Log Monitor";
    homepage = "https://github.com/SSLMate/certspotter";
    changelog = "https://github.com/SSLMate/certspotter/blob/${src.rev}/CHANGELOG.md";
    license = licenses.mpl20;
    mainProgram = "certspotter";
    maintainers = with maintainers; [ chayleaf ];
  };
}
