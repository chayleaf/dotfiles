{ pkgs, lib, ... }:
let
  wrapKakoune = { extraPackages ? [] , withPython3 ? true,  extraPython3Packages ? (_: []) }:
  pkgs.symlinkJoin {
    postBuild = ''
      rm $out/bin/kak
      makeWrapper ${lib.escapeShellArgs
        [ "${pkgs.kakoune-unwrapped}/bin/kak" "${placeholder "out"}/bin/kak"
          "--suffix" "PATH" ":" (lib.makeBinPath (extraPackages ++ [ (pkgs.python3.withPackages extraPython3Packages) ])) ]}
    '';
    buildInputs = [ pkgs.makeWrapper ]; preferLocalBuild = true;
    name = "kakoune${pkgs.kakoune-unwrapped.version}"; paths = [ pkgs.kakoune-unwrapped ];
    passthru.unwrapped = pkgs.kakoune-unwrapped; inherit (pkgs.kakoune-unwrapped) meta version;
  };
in {
  programs.kakoune = {
    enable = true;
    package = wrapKakoune {
      extraPackages = with pkgs; [
        rust-analyzer
        nodePackages.bash-language-server shellcheck
        nodePackages.typescript-language-server
        clang-tools_latest
        nodePackages.vscode-langservers-extracted
        nil
        marksman
        taplo
      ];
      extraPython3Packages = (pypkgs: with pypkgs; [ python-lsp-server ]);
    };
    config = {
      # colorScheme
      ui.changeColors = false;
    };
    extraConfig = ''
      eval %sh{kak-lsp --kakoune -s $kak_session}
      lsp-enable
      hook global BufOpenFile .* autoconfigtab
      hook global BufNewFile .* autoconfigtab
    '';
    plugins = with pkgs.kakounePlugins; [ kak-lsp smarttab-kak tabs-kak ]; 
  };
  xdg.configFile."kak-lsp/kak-lsp.toml".text = ''
    # bash, clangd, json, html, css, python work out of the box
    [language.rust]
    filetypes = ["rust"]
    roots = ["rust-toolchain.toml", "rust-toolchain", "Cargo.toml"]
    command = "rust-analyzer"
    [language.typescript]
    filetypes = ["typescript"]
    roots = ["package.json"]
    command = "typescript-language-server"
    args = ["--stdio"]
    [language.nix]
    filetypes = ["nix"]
    roots = ["flake.nix"]
    command = "nil"
    [language.markdown]
    filetypes = ["markdown"]
    roots = []
    command = "marksman"
    [language.toml]
    filetypes = ["toml"]
    roots = []
    command = "taplo"
  '';
}
