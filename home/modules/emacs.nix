{ pkgs, ... }:
{
  home.packages = with pkgs; [
    emacs
    proxychains
    rust-analyzer
    shellcheck
    llvmPackages_latest.clang-tools
    llvmPackages_latest.lldb
    nodePackages_latest.svelte-language-server
    nodePackages_latest.bash-language-server
    nodePackages_latest.typescript-language-server
    nodePackages_latest.vscode-langservers-extracted
    ripgrep
    (python3.withPackages (
      p: with p; [
        python-lsp-server
        python-lsp-black
        pylsp-mypy
        python-lsp-server.optional-dependencies.pyflakes
        python-lsp-server.optional-dependencies.mccabe
        python-lsp-server.optional-dependencies.pycodestyle
      ]
    ))
    nodePackages.bash-language-server
    nodePackages.typescript-language-server
    nil
    nixfmt-rfc-style
    marksman
    taplo
    csharp-ls
    fsautocomplete
    fantomas
    haskell-language-server
  ];
}
