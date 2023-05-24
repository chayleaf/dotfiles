{ config, pkgs, lib, ... }:
let
  wrapHelix = { extraPackages ? [] , withPython3 ? true,  extraPython3Packages ? (_: []) }:
  pkgs.symlinkJoin {
    postBuild = ''
      rm $out/bin/hx
      makeWrapper ${lib.escapeShellArgs (
        [ "${pkgs.helix}/bin/hx" "${placeholder "out"}/bin/hx" ]
        ++ [ "--suffix" "PATH" ":" (lib.makeBinPath (extraPackages ++ [(pkgs.python3.withPackages extraPython3Packages)])) ]
      )}
    '';
    buildInputs = [ pkgs.makeWrapper ]; preferLocalBuild = true;
    name = "helix${pkgs.helix.version}"; paths = [ pkgs.helix ];
    passthru.unwrapped = pkgs.helix; meta = pkgs.helix.meta; version = pkgs.helix.version;
  };
in {
  programs.helix = {
    enable = true;
    package = wrapHelix {
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
    # languages = [];
    settings = {
      theme = "base16_terminal";
    };
  };
}
