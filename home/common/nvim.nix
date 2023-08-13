{ config, pkgs, lib, notlua, ... }:
{
  imports = [ ./options.nix ];
  /*
  VIM config backup:
  syntax on
  au FileType markdown set colorcolumn=73 textwidth=72
  au FileType gitcommit set colorcolumn=73
  highlight NormalFloat guibg=NONE
  au BufReadPre * set foldmethod=syntax
  au BufReadPost * folddoc foldopen!
  autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
  */

  # welcome to my cursed DSL
  programs.neovim = let
    notlua-nvim = notlua.neovim { inherit (config.programs.neovim) plugins extraLuaPackages; };
    inherit (notlua.keywords)
      AND APPLY CALL DEFUN
      ELSE EQ GE IDX IF
      LE LET LETREC OR
      PROP RETURN SET;
    inherit (notlua.utils) compile;
    inherit (notlua-nvim.stdlib) vim string require print;
    inherit (notlua-nvim.keywords) REQ REQ';
  in let
    vimg = name: PROP vim.g name;
    # _ is basically semicolon
    _ = { __IS_SEPARATOR = true; };
    splitList = sep: list:
      let
        ivPairs = lib.imap0 (i: x: { inherit i x; }) list;
        is' = map ({ i, ... }: i) (builtins.filter ({ x, ... }: sep == x) ivPairs);
        is = [ 0 ] ++ (map (x: x + 1) is');
        ie = is' ++ [ (builtins.length list) ];
        se = lib.zipLists is ie;
      in
        map ({ fst, snd }: lib.sublist fst (snd - fst) list) se;
    # this transforms [ a b _ c _ d _ e f g ] into [ (a b) c d (RETURN (e f g)) ]
    L = args:
      let
        spl = splitList _ args;
        body = lib.init spl;
        ret = lib.last spl;
      in
      (map
        (list: builtins.foldl' lib.id (builtins.head list) (builtins.tail list))
        body) ++ (if ret == [] then [] else [(APPLY RETURN ret)]);
    keymapSetSingle = opts@{
      mode,
      lhs,
      rhs,
      noremap ? true,
      silent ? true,
      ...
    }: let
      opts'' = opts // { inherit noremap silent; };
      opts' = lib.filterAttrs (k: v:
        k != "keys" && k != "mode" && k != "lhs" && k != "rhs" && k != "desc"
        # defaults to false
        && ((k != "silent" && k != "noremap") || (builtins.isBool v && v))) opts'';
      in vim.keymap.set mode lhs rhs opts';
    keymapSetMulti = opts@{
      keys,
      mode,
      noremap ? true,
      silent ? true,
      ...
    }: let
      opts'' = opts // { inherit noremap silent; };
      opts' = lib.filterAttrs (k: v:
        k != "keys" && k != "lhs" && k != "rhs" && k != "desc"
        # defaults to false
        && ((k != "silent" && k != "noremap") || (builtins.isBool v && v))) opts'';
      in (lib.mapAttrsToList (k: {rhs, desc}: keymapSetSingle (opts' // {
        lhs = k; inherit rhs;
      })) keys) ++ [
        (which-key.register (lib.mapAttrs (k: v: [v.rhs v.desc]) keys) opts')
      ];
    keymapSetNs = args: keymapSetMulti (args // { mode = "n"; });
    kmSetNs = keys: keymapSetNs { inherit keys; };
    keymapSetVs = args: keymapSetMulti (args // { mode = "v"; });
    kmSetVs = keys: keymapSetVs { inherit keys; };

    which-key = REQ "which-key";
    luasnip = REQ "luasnip";
    compile' = name: stmts: compile name (L stmts);
  in {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim-unwrapped;
    extraPackages = with pkgs; [
      rust-analyzer
      nodePackages_latest.bash-language-server shellcheck
      nodePackages_latest.typescript-language-server
      # nodePackages_latest.svelte-language-server
      clang-tools_latest
      nodePackages_latest.vscode-langservers-extracted
      nil
      marksman
      taplo
      ripgrep
      (python3.withPackages (p: with p; [
        python-lsp-server
        pylsp-mypy
        python-lsp-server.optional-dependencies.pyflakes
        python-lsp-server.optional-dependencies.mccabe
        python-lsp-server.optional-dependencies.pycodestyle
      ]))
    ];
    # extraPython3Packages = pyPkgs: with pyPkgs; [
    # ];
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraLuaConfig = (compile' "main" [
      kmSetNs {
        "<C-X>" = {
          rhs = DEFUN (vim.fn.system [ "chmod" "+x" (vim.fn.expand "%") ]);
          desc = "chmod +x %";
        };
      } _
      SET (vimg "vimsyn_embed") "l" _
      LET (vim.api.nvim_create_augroup "nvimrc" { clear = true; }) (group:
        lib.mapAttrsToList (k: v: vim.api.nvim_create_autocmd k { inherit group; callback = v; }) {
          BufReadPre = DEFUN (SET vim.o.foldmethod "syntax");
          BufEnter = { buf, ... }:
            LET (vim.filetype.match { inherit buf; }) (filetype: L [
              IF (APPLY OR (map (EQ filetype) [ "gitcommit" "markdown" ])) (
                LET vim.o.colorcolumn (old_colorcolumn: L [
                  SET vim.o.colorcolumn "73" _
                  vim.api.nvim_create_autocmd "BufLeave" {
                    buffer = buf;
                    callback = DEFUN (L [
                      SET vim.o.colorcolumn old_colorcolumn _
                      # return true = delete autocommand
                      true
                    ]);
                  } _
                ])
              ) _
              IF (EQ filetype "markdown") (
                (SET (IDX vim.bo buf).textwidth 72)
              ) _
            ]);
          BufWinEnter = { buf, ... }:
            LET (vim.filetype.match { inherit buf; }) (filetype: L [
              CALL (PROP vim.cmd "folddoc") "foldopen!" _
              IF (EQ filetype "gitcommit") (
                vim.cmd {
                  cmd = "normal"; bang = true;
                  args = [ "gg" ];
                }
              ) ELSE (LET
                (IDX (vim.api.nvim_buf_get_mark buf "\"") 1)
                (vim.api.nvim_buf_line_count buf)
              (pos: cnt:
                IF (AND (GE pos 1) (LE pos cnt))
                  (vim.cmd {
                    cmd = "normal"; bang = true;
                    args = [ "g`\"" ];
                  })
                /*ELIF*/ (GE pos 1)
                  (vim.cmd {
                    cmd = "normal"; bang = true;
                    args = [ "g$" ];
                  })
                ELSE
                  (vim.cmd {
                    cmd = "normal"; bang = true;
                    args = [ "gg" ];
                  })
              )) _
            ]);
        }
      ) _
    ]);
    plugins = let ps = pkgs.vimPlugins; in map (x: if x?config && x?plugin then { type = "lua"; } // x else x) [
      ps.vim-svelte
      # TODO remove on next nvim update (0.8.3/0.9? whenever they add builtin nix syntax)
      # testing the removal
      # ps.vim-nix
      { plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
          pname = "vscode-nvim";
          version = "2023-02-10";
          src = pkgs.fetchFromGitHub {
            owner = "Mofiqul";
            repo = "vscode.nvim";
            rev = "db9ee339b5556aa832ca58871fd18f9467a18520";
            sha256 = "sha256-X2IgIjO5NNq7vJdl09hBY1TFqHlsfF1xfllKr4osILI=";
          };
        };
        config = compile' "vscode_nvim" [
          (REQ "vscode").setup {
            transparent = true;
            color_overrides = {
              vscGray = "#745b5f";
              vscViolet = "#${config.colors.magenta}";
              vscBlue = "#6ddfd8";
              vscDarkBlue = "#${config.colors.blue}";
              vscGreen = "#${config.colors.green}";
              vscBlueGreen = "#73bf88";
              vscLightGreen = "#6acf6e";
              vscRed = "#${config.colors.red}";
              vscOrange = "#e89666";
              vscLightRed = "#e64e4e";
              vscYellowOrange = "#e8b166";
              vscYellow = "#${config.colors.yellow}";
              vscPink = "#cf83c4";
            };
          } _
          vim.api.nvim_set_hl 0 "NormalFloat" {
            bg = "NONE";
          } _
        ]; }
      { plugin = ps.nvim-web-devicons;
        config = compile "nvim_web_devicons" ((REQ "nvim-web-devicons").setup { }); }
      { plugin = ps.nvim-tree-lua;
        config = compile "nvim_tree_lua" (LET (REQ "nvim-tree") (REQ "nvim-tree.api") (nvim-tree: nvim-tree-api: L [
          SET (vimg "loaded_netrw") 1 _
          SET (vimg "loaded_netrwPlugin") 1 _
          SET vim.o.termguicolors true _
          nvim-tree.setup { } _ # :help nvim-tree-setup
          kmSetNs {
            "<C-N>" = {
              rhs = nvim-tree-api.tree.toggle;
              desc = "Toggle NvimTree";
            };
          } _
        ])); }
      ps.vim-sleuth
      ps.luasnip
      { plugin = ps.nvim-cmp;
        config = let
          border = (name: [
            [ "╭" name ]
            [ "─" name ]
            [ "╮" name ]
            [ "│" name ]
            [ "╯" name ]
            [ "─" name ]
            [ "╰" name ]
            [ "│" name ]
          ]);
        in compile "nvim_cmp" (LET (REQ "cmp") (REQ "lspkind") (cmp: lspkind:
          # call is required because cmp.setup is a table
          cmp.setup {
            snippet = {
              expand = { body, ... }: luasnip.lsp_expand body { };
            };
            view = { };
            window = {
              completion = {
                border = border "CmpBorder";
                winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:None";
              };
              documentation = {
                border = border "CmpDocBorder";
              };
            };
            formatting = {
              format = entry: vim_item: let kind = PROP vim_item "kind"; in L [
                SET kind (string.format "%s %s" (IDX lspkind kind) kind) _
                vim_item
              ];
            };
            mapping = {
              "<C-p>" = cmp.mapping.select_prev_item { };
              "<C-n>" = cmp.mapping.select_next_item { };
              "<C-space>" = cmp.mapping.complete { };
              "<C-e>" = CALL cmp.mapping.close;
              "<cr>" = cmp.mapping.confirm {
                behavior = cmp.ConfirmBehavior.Replace;
                select = false;
              };
              "<tab>" = cmp.mapping (fallback:
                IF (CALL cmp.visible) (
                  CALL cmp.select_next_item
                ) /*(CALL luasnip.expand_or_jumpable) (
                  vim.api.nvim_feedkeys
                    (vim.api.nvim_replace_termcodes "<Plug>luasnip-expand-or-jump" true true true)
                    ""
                    false
                )*/ ELSE (
                  CALL fallback
                )
              ) [ "i" "s" ];
              "<S-tab>" = cmp.mapping (fallback:
                IF (CALL cmp.visible) (
                  CALL cmp.select_prev_item
                ) /*(luasnip.jumpable (-1)) (
                  vim.api.nvim_feedkeys
                    (vim.api.nvim_replace_termcodes "<Plug>luasnip-jump-prev" true true true)
                    ""
                    false
                )*/ ELSE (
                  CALL fallback
                )
              ) [ "i" "s" ];
            };
            sources = cmp.config.sources [
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
            ];
          }
        )); }
      ps.lspkind-nvim
      ps.cmp_luasnip
      ps.cmp-nvim-lsp
      { plugin = ps.nvim-autopairs;
        config = compile "nvim_autopairs" (LET
          (REQ "cmp") (REQ "nvim-autopairs.completion.cmp") (REQ "nvim-autopairs")
          (cmp: cmp-autopairs: nvim-autopairs:
        L [
          nvim-autopairs.setup {
            disable_filetype = [ "TelescopePrompt" "vim" ];
          } _
          cmp.event.on cmp.event "confirm_done" (cmp-autopairs.on_confirm_done { }) _
        ])); }
      { plugin = ps.comment-nvim;
        config = compile' "comment_nvim" [
          (REQ "Comment").setup { } _
          kmSetNs {
            "<space>/" = {
              # metatables......
              rhs = REQ' (PROP (require "Comment.api") "toggle.linewise.current");
              desc = "Comment current line";
            };
          } _
          kmSetVs {
            "<space>/" = {
              rhs = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>";
              desc = "Comment selection";
            };
          } _
        ]; }
      { plugin = ps.nvim-lspconfig;
        config = compile "nvim_lspconfig" (
          let lsp = name: builtins.seq
            # ensure an lsp exists (otherwise lspconfig will still create an empty config for some reason)
            (REQ "lspconfig.server_configurations.${name}")
            # metatables, son! they harden in response to physical trauma
            (REQ' (PROP (require "lspconfig") name));
          in L [
          # See `:help vim.diagnostic.*` for documentation on any of the below functions
          kmSetNs {
            "<space>e" = {
              rhs = vim.diagnostic.open_float;
              desc = "Show diagnostics in a floating window.";
            };
            "[d" = {
              rhs = vim.diagnostic.goto_prev;
              desc = "Move to the previous diagnostic in the current buffer.";
            };
            "]d" = {
              rhs = vim.diagnostic.goto_next;
              desc = "Get the next diagnostic closest to the cursor position.";
            };
            "<space>q" = {
              rhs = vim.diagnostic.setloclist;
              desc = "Add buffer diagnostics to the location list.";
            };
          } _
          LET
            # LET on_attach
            (client: bufnr: L [
              SET (IDX vim.bo bufnr).omnifunc "v:lua.vim.lsp.omnifunc" _
              # Mappings.
              # See `:help vim.lsp.*` for documentation on any of the below functions
              keymapSetNs {
                buffer = bufnr;
                keys = {
                  "gD" = {
                    rhs = vim.lsp.buf.declaration;
                    desc = "Jumps to the declaration of the symbol under the cursor."; };
                  "gd" = {
                    rhs = vim.lsp.buf.definition;
                    desc = "Jumps to the definition of the symbol under the cursor."; };
                  "K" = {
                    rhs = vim.lsp.buf.hover;
                    desc = "Displays hover information about the symbol under the cursor in a floating window."; };
                  "gi" = {
                    rhs = vim.lsp.buf.implementation;
                    desc = "Lists all the implementations for the symbol under the cursor in the quickfix window."; };
                  "<C-h>" = {
                    rhs = vim.lsp.buf.signature_help;
                    desc = "Displays signature information about the symbol under the cursor in a floating window."; };
                  "<space>wa" = {
                    rhs = vim.lsp.buf.add_workspace_folder;
                    desc = "Add a folder to the workspace folders."; };
                  "<space>wr" = {
                    rhs = vim.lsp.buf.remove_workspace_folder;
                    desc = "Remove a folder from the workspace folders."; };
                  "<space>wl" = {
                    rhs = DEFUN (print (vim.inspect (CALL vim.lsp.buf.list_workspace_folders) {}));
                    desc = "List workspace folders."; };
                  "<space>D" = {
                    rhs = vim.lsp.buf.type_definition;
                    desc = "Jumps to the definition of the type of the symbol under the cursor."; };
                  "<space>rn" = {
                    rhs = vim.lsp.buf.rename;
                    desc = "Rename old_fname to new_fname"; };
                  "<space>ca" = {
                    rhs = vim.lsp.buf.code_action;
                    desc = "Selects a code action available at the current cursor position."; };
                  "gr" = {
                    rhs = vim.lsp.buf.references;
                    desc = "Lists all the references to the symbol under the cursor in the quickfix window."; };
                  "<space>f" = {
                    rhs = DEFUN (vim.lsp.buf.format { async = true; });
                    desc = "Formats a buffer."; };
                };
              } _
            ])
            # LET rust_settings
            { rust-analyzer = {
              assist.emitMustUse = true;
              cargo.buildScripts.enable = true;
              check.command = "clippy";
              procMacro.enable = true;
            }; }
            # LET capabilities
            (vim.tbl_extend
              "keep"
              ((REQ "cmp_nvim_lsp").default_capabilities { })
              (CALL vim.lsp.protocol.make_client_capabilities))
          # BEGIN
          (on_attach: rust_settings: capabilities:
            LETREC
            # LETREC on_attach_rust
            (on_attach_rust: client: bufnr: L [
              vim.api.nvim_buf_create_user_command bufnr "RustAndroid" (opts: L [
                vim.lsp.set_log_level "debug" _
                (lsp "rust_analyzer").setup {
                  on_attach = on_attach_rust;
                  inherit capabilities;
                  settings = vim.tbl_deep_extend
                    "keep"
                    config.rustAnalyzerAndroidSettings
                    rust_settings;
                } _
              ]) {} _
              on_attach client bufnr _
            ])
            # BEGIN
            (let setupLsp = name: args: (lsp name).setup ({
              inherit on_attach capabilities;
              settings = { };
            } // args);
            in on_attach_rust: L [
              # vim.lsp.set_log_level "debug" _
              # see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
              lib.mapAttrsToList setupLsp {
                bashls = { };
                clangd = { };
                # https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
                pylsp = {
                  settings = {
                    pylsp.plugins.pylsp_mypy.enabled = true;
                  };
                };
                svelte = { };
                html = { };
                cssls = { };
                tsserver = { };
                jsonls = { };
                nil_ls = { };
                taplo = { };
                marksman = { };
                rust_analyzer = {
                  on_attach = on_attach_rust;
                  settings = rust_settings;
                };
              } _
            ]) # END
          ) _ # END
        ]); }
      { plugin = ps.which-key-nvim;
        config = compile' "which_key_nvim" [
          SET vim.o.timeout true _
          SET vim.o.timeoutlen 500 _
          which-key.setup { } _
        ]; }
    ];
  };
}
