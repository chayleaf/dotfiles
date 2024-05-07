{ lib, callPackage, autoconf, hexdump, perl, python3, wineUnstable, path }:

with callPackage "${path}/pkgs/applications/emulators/wine/util.nix" {};

let patch = (callPackage ./sources.nix {}).staging;
    build-inputs = pkgNames: extra:
      (mkBuildInputs wineUnstable.pkgArches pkgNames) ++ extra;
  patchList = lib.mapAttrsToList (k: v: ./patches/${k}) (builtins.readDir ./patches);
in assert lib.versions.majorMinor wineUnstable.version == lib.versions.majorMinor patch.version;

(lib.overrideDerivation (wineUnstable.override { wineRelease = "staging"; }) (self: {
  buildInputs = build-inputs [ "perl" "util-linux" "autoconf" "gitMinimal" ] self.buildInputs;
  nativeBuildInputs = [ autoconf hexdump perl python3 ] ++ self.nativeBuildInputs;

  prePatch = self.prePatch or "" + ''
    patchShebangs tools
    cp -r ${patch}/patches ${patch}/staging .
    chmod +w patches
    patchShebangs ./patches/gitapply.sh
    python3 ./staging/patchinstall.py DESTDIR="$PWD" --all ${lib.concatMapStringsSep " " (ps: "-W ${ps}") patch.disabledPatchsets}
    for dir in $(ls ${./audio-revert}); do
      rm -rf dlls/$dir
      cp -r ${./audio-revert}/$dir dlls
      chmod -R +w dlls/$dir
    done
    for patch in ${builtins.concatStringsSep " " patchList}; do
      echo "Applying $patch"
      patch -p1 < "$patch"
    done
  '';
})) // {
  meta = wineUnstable.meta // {
    description = wineUnstable.meta.description + " (with osu-wine patches)";
  };
}
