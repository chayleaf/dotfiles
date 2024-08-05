{ krita, python3Packages }:

(krita.override {
  unwrapped = krita.unwrapped.overrideAttrs (old: { patches = old.patches or [] ++ [
    ./painting-api.patch
    ./fix-painting-api-crashes.patch
    ./painting-api-options.patch
    ./painting-api-pressure.patch
  ]; });
}).overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [ python3Packages.requests ];
})
