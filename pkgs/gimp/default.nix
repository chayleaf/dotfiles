{ lib
, gimp
, fetchFromGitHub
, substituteAll
, fetchpatch
, meson
, ninja
, pkg-config
, gettext
, gtk3
, graphviz
, libarchive
, luajit
, python3
, wrapGAppsHook
, libxslt
, gobject-introspection
, vala
, gi-docgen
, perl
, appstream-glib
, desktop-file-utils
, json-glib
, gjs
, xorg
, xvfb-run
, dbus
, adwaita-icon-theme
, alsa-lib
, glib
, glib-networking
, libiff
, libilbm
, cfitsio
}:

let
  python = python3.withPackages (pp: with pp; [
    pygobject3
  ]);
in gimp.overrideAttrs (old: rec {
  version = "2_99_18+date=2024-02-18";
  outputs = [ "out" "dev" "devdoc" ];
  src = fetchFromGitHub {
    owner = "GNOME";
    repo = "gimp";
    rev = "f94c4cb5dbf9766b27ecb5016b7a39497cc74ddc";
    hash = "sha256-rQd/EwGk6AFQ4dQCx2Jys60mcDvaLSkXeVsrjTJw8wg=";
  };
  patches = [
    (substituteAll {
      src = ./hardcode-plugin-interpreters.patch;
      python_interpreter = python.interpreter;
    })
    (substituteAll {
      src = fetchpatch {
        url = "https://raw.githubusercontent.com/NixOS/nixpkgs/86947c8f83a3bd593eefb8e5f433f0d045c3d9a7/pkgs/applications/graphics/gimp/tests-dbus-conf.patch";
        hash = "sha256-XEsYmrNcuF6i4/EwTbXZ+vI6zY9iLbasn0I5EHhwLWU=";
      };
      session_conf = "${dbus.out}/share/dbus-1/session.conf";
    })
    (fetchpatch {
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/86947c8f83a3bd593eefb8e5f433f0d045c3d9a7/pkgs/applications/graphics/gimp/fix-isocodes-paths.patch";
      hash = "sha256-8jqQmfbOARMPNIsBfNKpMIeK4dXoAme7rUJeQZwh4PM=";
    })
    ./floating-paste.patch
    ./fix-docs.patch
  ];
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    gettext
    wrapGAppsHook
    libxslt
    gobject-introspection
    perl
    vala
    gi-docgen
    desktop-file-utils
    xvfb-run
    dbus
  ];
  buildInputs = builtins.filter (x: !builtins.elem (lib.getName x) ["gtk2"]) old.buildInputs
  ++ [
    appstream-glib
    gtk3
    libarchive
    json-glib
    python
    xorg.libXmu
    adwaita-icon-theme
    (luajit.withPackages (ps: [ ps.lgi ]))
    alsa-lib
    gjs
    libiff
    libilbm
    cfitsio
  ];
  configureFlags = [ ];
  mesonFlags = [
    "-Dbug-report-url=https://github.com/NixOS/nixpkgs/issues/new"
    "-Dicc-directory=/run/current-system/sw/share/color/icc"
    "-Dcheck-update=no"
    "-Dappdata-test=disabled"
  ];
  env = old.env // { GIO_EXTRA_MODULES = "${glib-networking}/lib/gio/modules"; };
  preConfigure = "";
  postPatch = ''
    patchShebangs \
      app/tests/create_test_env.sh \
      tools/gimp-mkenums
    substitute app/git-version.h.in git-version.h \
      --subst-var-by GIMP_GIT_VERSION "GIMP_2.99.?-g${builtins.substring 0 10 src.rev}" \
      --subst-var-by GIMP_GIT_VERSION_ABBREV "${builtins.substring 0 10 src.rev}" \
      --subst-var-by GIMP_GIT_LAST_COMMIT_YEAR "${builtins.head (builtins.match ".+\+date=([0-9]{4})-[0-9]{2}-[0-9]{2}" version)}"
  '';

  preCheck = ''
    export NO_AT_BRIDGE=1
    export HOME="$TMPDIR"
    export XDG_DATA_DIRS="${glib.getSchemaDataDirPath gtk3}:$XDG_DATA_DIRS"
  '';
  checkPhase = ''
    runHook preCheck
    meson test --timeout-multiplier 4 --print-errorlogs
    runHook postCheck
  '';
  doCheck = false;
  preFixup = ''
    gappsWrapperArgs+=(\
      --prefix PATH : "${lib.makeBinPath [ graphviz ]}:$out/bin" \
      --suffix XDG_DATA_DIRS : "${adwaita-icon-theme}/share" \
    )
  '';
  postFixup = ''
    moveToOutput "share/doc" "$devdoc"
  '';

  passthru = old.passthru // {
    majorVersion = "2.99";
    gtk = gtk3;
  };
})
