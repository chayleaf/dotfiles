{ lib
, fetchFromGitHub
, buildNpmPackage
, fetchNpmDeps
, nodejs
}:

let
  version = "2.27.0";
  src = fetchFromGitHub {
    owner = "sbs20";
    repo = "scanservjs";
    rev = "v${version}";
    hash = "sha256-GFpfH7YSXFRNRmx8F2bUJsGdPW1ECT7AQquJRxiRJEU=";
  };

  depsHashes = {
    server = "sha256-V4w4euMl67eS4WNIFM8j06/JAEudaq+4zY9pFVgTmlY=";
    client = "sha256-r/uYaXpQnlI90Yn6mo2KViKDMHE8zaCAxNFnEZslnaY=";
  };

  serverDepsForClient = fetchNpmDeps {
    inherit src nodejs;
    sourceRoot = "${src.name}/packages/server";
    name = "scanservjs-server";
    hash = depsHashes.server or lib.fakeHash;
  };

  # static client files
  client = buildNpmPackage ({
    pname = "scanservjs-static";
    inherit version src nodejs;

    sourceRoot = "${src.name}/packages/client";
    npmDepsHash = depsHashes.client or lib.fakeHash;

    preBuild = ''
      cd ../server
      chmod +w package-lock.json . /build/source/
      npmDeps=${serverDepsForClient} npmConfigHook
      cd ../client
    '';

    env.NODE_OPTIONS = "--openssl-legacy-provider";

    dontNpmInstall = true;
    installPhase = ''
      mv /build/source/dist/client $out
    '';
  });

in buildNpmPackage {
  pname = "scanservjs";
  inherit version src nodejs;

  sourceRoot = "${src.name}/packages/server";
  npmDepsHash = depsHashes.server or lib.fakeHash;

  preBuild = ''
    chmod +w /build/source
    substituteInPlace src/server.js --replace "express.static('client')" "express.static('${client}')"
    substituteInPlace src/api.js --replace \
      '`''${config.previewDirectory}/default.jpg`' \
      "'$out/lib/node_modules/scanservjs-api/data/preview/default.jpg'"
    substituteInPlace src/application.js --replace \
      "'../../config/config.local.js'" \
      "process.env.NIX_SCANSERVJS_CONFIG_PATH"
    substituteInPlace src/classes/user-options.js --replace \
      "const localPath = path.join(__dirname, localConfigPath);" \
      "const localPath = localConfigPath;"
    substituteInPlace src/configure.js --replace \
      "fs.mkdirSync(config.outputDirectory, { recursive: true });" \
      "fs.mkdirSync(config.outputDirectory, { recursive: true }); fs.mkdirSync(config.previewDirectory, { recursive: true });"
  '';

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/scanservjs \
      --set NODE_ENV production \
      --add-flags "'$out/lib/node_modules/scanservjs-api/src/server.js'"
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
