{ pkgs, lib, ... }:
let
  helix = pkgs.helix.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        name = "change-number-selection-behavior.patch";
        url = "https://github.com/helix-editor/helix/commit/b8d067015a69635a8ff0cc66e152750434688299.patch";
        hash = "sha256-1Z/prgF/LVakUPC0OZkE/0amc8M8SkV3JygK9vbdEuI=";
      })
    ];
  });
  wrapHelix =
    {
      extraPackages ? [ ],
      withPython3 ? true,
      extraPython3Packages ? (_: [ ]),
    }:
    pkgs.symlinkJoin {
      postBuild = ''
        rm $out/bin/hx
        makeWrapper ${
          lib.escapeShellArgs [
            "${helix}/bin/hx"
            "${placeholder "out"}/bin/hx"
            "--suffix"
            "PATH"
            ":"
            (lib.makeBinPath (extraPackages ++ [ (pkgs.python3.withPackages extraPython3Packages) ]))
          ]
        }
      '';
      buildInputs = [ pkgs.makeWrapper ];
      preferLocalBuild = true;
      name = "helix${helix.version}";
      paths = [ helix ];
      passthru.unwrapped = helix;
      inherit (helix) meta version;
    };
in
{
  programs.helix = {
    enable = true;
    package = wrapHelix {
      extraPackages = with pkgs; [
        rust-analyzer
        bash-language-server
        shellcheck
        typescript-language-server
        llvmPackages_latest.clang-tools
        llvmPackages_latest.lldb
        vscode-langservers-extracted
        typescript-go
        nil
        nixfmt-rfc-style
        marksman
        taplo
        csharp-ls
        fsautocomplete
        fantomas
        haskell-language-server
      ];
      extraPython3Packages = (
        pypkgs: with pypkgs; [
          python-lsp-server
          python-lsp-black
          pylsp-mypy
          python-lsp-server.optional-dependencies.pyflakes
          python-lsp-server.optional-dependencies.mccabe
          python-lsp-server.optional-dependencies.pycodestyle
        ]
      );
    };
    languages = {
      language-server.typescript-go = {
        command = "tsgo";
        args = [
          "--lsp"
          "--stdio"
        ];
      };
      language =
        map
          (x: {
            name = x;
            language-servers = [ "typescript-go" ];
          })
          [
            "javascript"
            "jsx"
            "tsx"
            "typescript"
          ]
        ++
          map
            (x: {
              name = x;
              language-servers = [
                "typescript-go"
                "vscode-eslint-language-server"
                "ember-language-server"
              ];
            })
            [
              "gjs"
              "gts"
            ];
    };
    themes.custom = {
      inherits = "base16_transparent";

      "attribute".fg = "light-blue";

      "type".fg = "blue-green";
      "type.builtin".fg = "blue";
      "type.enum.variant".fg = "yellow";

      "constructor".fg = "blue-green";
      "constant".fg = "yellow";
      "constant.builtin".fg = "blue";
      "constant.character".fg = "orange";
      "constant.character.escape".fg = "yellow-orange";
      "constant.numeric".fg = "light-green";

      "string".fg = "orange";

      "comment".fg = "green";

      "variable".fg = "default";
      "variable.other.member".fg = "default";
      "label".fg = "light-blue";

      "keyword".fg = "pink";
      "keyword.operator".fg = "blue";
      "keyword.function".fg = "blue";

      "function".fg = "yellow";
      "function.macro".fg = "blue-green";
      "function.special".fg = "blue-green";

      "tag".fg = "blue";

      "namespace".fg = "default";

      "special".fg = "blue-green";

      "markup.link.url".fg = "yellow";

      palette = {
        gray = "#745b5f";
        violet = "#a64999";
        blue = "#6ddfd8";
        dark-blue = "#5968b3";
        light-blue = "#9cdcfe";
        green = "#8cbf73";
        blue-green = "#73bf88";
        light-green = "#6acf6e";
        red = "#e66e6e";
        orange = "#e89666";
        light-red = "#e64e4e";
        yellow-orange = "#e8b166";
        yellow = "#ebbe5f";
        pink = "#cf83c4";
      };
    };
    settings = {
      theme = "custom";
      editor.auto-format = false;
      editor.bufferline = "always";
      editor.cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "block";
      };
      editor.search.smart-case = false;
      editor.smart-tab.enable = false;
    };
  };
}
