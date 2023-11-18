{ lib
, fetchFromGitHub
, buildNpmPackage
, nodejs
}:

buildNpmPackage {
  pname = "scanservjs";
  version = "3.0.3";

  src = fetchFromGitHub {
    # owner = "sbs20";
    owner = "chayleaf";
    repo = "scanservjs";
    # rev = "v${version}";
    rev = "bf41a95c9cd6bd924d6e14a28da6d33ddc64ef2e";
    hash = "sha256-ePg8spI1rlWYcpjtax7gaZp2wUX4beHzMd71b8XKNG8=";
  };

  inherit nodejs;

  npmDepsHash = "sha256-bigIFAQ2RLk6yxbUcMnmXwgaEkzFFUYn+hE7RIiFm8Y=";

  preBuild = ''
    npm run build
  '';

  postInstall = ''
    mv $out/lib/node_modules/scanservjs/node_modules dist/
    rm -rf $out/lib/node_modules/scanservjs
    mv dist $out/lib/node_modules/scanservjs
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/scanservjs \
      --set NODE_ENV production \
      --add-flags "'$out/lib/node_modules/scanservjs/server/server.js'"
  '';

  meta = with lib; {
    description = "SANE scanner nodejs web ui";
    longDescription = "scanservjs is a simple web-based UI for SANE which allows you to share a scanner on a network without the need for drivers or complicated installation.";
    homepage = "https://github.com/sbs20/scanservjs";
    license = licenses.gpl2Only;
    mainProgram = "scanservjs";
    maintainers = with maintainers; [ chayleaf ];
  };
}
