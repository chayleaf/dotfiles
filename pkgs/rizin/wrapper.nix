{ makeWrapper
, symlinkJoin
, unwrapped
}:

plugins:

symlinkJoin {
  name = "cutter-with-plugins";

  paths = [ unwrapped ] ++ plugins;

  nativeBuildInputs = [ makeWrapper ];

  passthru = {
    inherit unwrapped;
  };

  postBuild = ''
    rm $out/bin/*
    wrapperArgs=(--set RZ_LIBR_PLUGINS $out/lib/rizin/plugins)
    if [ -d $out/share/rizin/cutter ]; then
      wrapperArgs+=(--prefix XDG_DATA_DIRS : $out/share)
    fi
    for binary in $(ls ${unwrapped}/bin); do
      makeWrapper ${unwrapped}/bin/$binary $out/bin/$binary "''${wrapperArgs[@]}"
    done
  '';
}
