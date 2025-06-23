{ krita, python3Packages }:

(krita.override {
  unwrapped = krita.unwrapped.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [
      ./painting-api.patch
      ./fix-painting-api-crashes.patch
      ./painting-api-options.patch
      ./painting-api-pressure.patch
      ./line-painting-api-qpointf.patch
      ./fixup.patch
    ];
  });
}).overrideAttrs
  (old: {
    patched = true;
    buildInputs = old.buildInputs ++ [ python3Packages.requests ];
  })
