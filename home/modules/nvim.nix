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
  programs.nixvim = let
    notlua-nvim = notlua.neovim {
      plugins = config.programs.nixvim.extraPlugins;
      inherit (config.programs.nixvim) extraLuaPackages;
    };
    inherit (notlua.keywords)
      AND APPLY CALL DEFUN ELSE EQ GE IDX IF
      LE LET LETREC MERGE OR PROP RETURN SET;
    inherit (notlua.utils) compile;
    inherit (notlua-nvim.stdlib) vim string require print;
    inherit (notlua-nvim.keywords) REQ REQ';
  in let
    vimg = name: PROP vim.g name;
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
        (which-key.add (MERGE
          ({
            inherit mode;
            remap = !noremap;
          } // builtins.removeAttrs opts ["keys" "noremap"])
          (lib.mapAttrsToList (k: v: (MERGE [ k v.rhs ] { inherit (v) desc; })) keys)
        ) null)
        # (which-key.register (lib.mapAttrs (k: v: [v.rhs v.desc]) keys) opts')
      ];
    keymapSetNs = args: keymapSetMulti (args // { mode = "n"; });
    kmSetNs = keys: keymapSetNs { inherit keys; };
    keymapSetVs = args: keymapSetMulti (args // { mode = "v"; });
    kmSetVs = keys: keymapSetVs { inherit keys; };

    which-key = REQ "which-key";
    luasnip = REQ "luasnip";

    plugins = let ps = pkgs.vimPlugins; in [
      ps.vim-svelte
      # vim-nix isn't necessary for syntax highlighting, but it improves overall editing experience
      ps.vim-nix
      { plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "vscode-nvim";
          version = "2023-02-10";
          src = pkgs.fetchFromGitHub {
            owner = "Mofiqul";
            repo = "vscode.nvim";
            rev = "db9ee339b5556aa832ca58871fd18f9467a18520";
            sha256 = "sha256-X2IgIjO5NNq7vJdl09hBY1TFqHlsfF1xfllKr4osILI=";
          };
        };
        config = [
          ((REQ "vscode").setup {
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
          })
          (vim.api.nvim_set_hl 0 "NormalFloat" {
            bg = "NONE";
          })
        ]; }
      { plugin = ps.nvim-web-devicons;
        config = ((REQ "nvim-web-devicons").setup { }); }
      { plugin = ps.nvim-tree-lua;
        config = (LET (REQ "nvim-tree") (REQ "nvim-tree.api") (nvim-tree: nvim-tree-api: [
          (SET (vimg "loaded_netrw") 1)
          (SET (vimg "loaded_netrwPlugin") 1)
          (SET vim.o.termguicolors true)
          (nvim-tree.setup { }) # :help nvim-tree-setup
          (kmSetNs {
            "<C-N>" = {
              rhs = nvim-tree-api.tree.toggle;
              desc = "Toggle NvimTree";
            };
          })
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
        in (LET (REQ "cmp") (REQ "lspkind") (cmp: lspkind:
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
              format = entry: vim_item: let kind = PROP vim_item "kind"; in [
                (SET kind (string.format "%s %s" (IDX lspkind kind) kind))
                (RETURN vim_item)
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
        config = (LET
          (REQ "cmp") (REQ "nvim-autopairs.completion.cmp") (REQ "nvim-autopairs")
          (cmp: cmp-autopairs: nvim-autopairs:
        [
          (nvim-autopairs.setup {
            disable_filetype = [ "TelescopePrompt" "vim" ];
          })
          (cmp.event.on cmp.event "confirm_done" (cmp-autopairs.on_confirm_done { }))
        ])); }
      { plugin = ps.comment-nvim;
        config = [
          ((REQ "Comment").setup { })
          (kmSetNs {
            "<space>/" = {
              # metatables......
              rhs = REQ' (PROP (require "Comment.api") "toggle.linewise.current");
              desc = "Comment current line";
            };
          })
          (kmSetVs {
            "<space>/" = {
              rhs = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>";
              desc = "Comment selection";
            };
          })
        ]; }
      { plugin = ps.nvim-lspconfig;
        config = (
          let lsp = name: builtins.seq
            # ensure an lsp exists (otherwise lspconfig will still create an empty config for some reason)
            (REQ "lspconfig.server_configurations.${name}")
            # metatables, son! they harden in response to physical trauma
            (REQ' (PROP (require "lspconfig") name));
          in [
          # See `:help vim.diagnostic.*` for documentation on any of the below functions
          (kmSetNs {
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
          })
          (LET
            # LET on_attach
            (client: bufnr: [
              (SET (IDX vim.bo bufnr).omnifunc "v:lua.vim.lsp.omnifunc")
              # Mappings.
              # See `:help vim.lsp.*` for documentation on any of the below functions
              (keymapSetNs {
                buffer = bufnr;
                keys = {
                  "gD" = { rhs = vim.lsp.buf.declaration; desc = "Jumps to the declaration of the symbol under the cursor."; };
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
              })
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
            (on_attach_rust: client: bufnr: [
              (vim.api.nvim_buf_create_user_command bufnr "RustAndroid" (opts: [
                (vim.lsp.set_log_level "debug")
                ((lsp "rust_analyzer").setup {
                  on_attach = on_attach_rust;
                  inherit capabilities;
                  settings = vim.tbl_deep_extend
                    "keep"
                    config.rustAnalyzerAndroidSettings
                    rust_settings;
                })
              ]) {})
              (on_attach client bufnr)
            ])
            # BEGIN
            (let setupLsp = name: args: (lsp name).setup ({
              inherit on_attach capabilities;
              settings = { };
            } // args);
            in on_attach_rust: [
              # (vim.lsp.set_log_level "debug")
              # see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
              (lib.mapAttrsToList setupLsp {
                bashls = { };
                clangd = { };
                # https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
                pylsp = {
                  settings.pylsp = {
                    plugins.pylsp_mypy.enabled = true;
                    plugins.black.enabled = true;
                  };
                };
                svelte = { };
                html = { };
                cssls = { };
                tsserver = { };
                jsonls = { };
                nil_ls = {
                  settings.nil = {
                    formatting.command = ["nixfmt"];
                  };
                };
                taplo = { };
                marksman = { };
                rust_analyzer = {
                  on_attach = on_attach_rust;
                  settings = rust_settings;
                };
              })
            ]) # END
          )) # END
        ]); }
      { plugin = ps.which-key-nvim;
        config = [
          (SET vim.o.timeout true)
          (SET vim.o.timeoutlen 500)
          (which-key.setup { })
        ]; }
    ];
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
      nixfmt-rfc-style
      taplo
      ripgrep
      (python3.withPackages (p: with p; [
        python-lsp-server
        python-lsp-black
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

    extraConfigLua = compile "main" (
      builtins.concatLists (map (x: if x?plugin then lib.toList x.config else [ ]) plugins) ++ [
      (kmSetNs {
        "<C-X>" = {
          rhs = DEFUN (vim.fn.system [ "chmod" "+x" (vim.fn.expand "%") ]);
          desc = "chmod +x %";
        };
      })
      (SET (vimg "vimsyn_embed") "l")
      (LET (vim.api.nvim_create_augroup "nvimrc" { clear = true; }) (group:
        lib.mapAttrsToList (k: v: vim.api.nvim_create_autocmd k { inherit group; callback = v; }) {
          BufReadPre = DEFUN (SET vim.o.foldmethod "syntax");
          BufEnter = { buf, ... }:
            LET (vim.filetype.match { inherit buf; }) (filetype: [
              (IF (APPLY OR (map (EQ filetype) [ "gitcommit" "markdown" "mail" ])) (
                LET vim.o.colorcolumn (old_colorcolumn: [
                  (SET vim.o.colorcolumn "73")
                  (vim.api.nvim_create_autocmd "BufLeave" {
                    buffer = buf;
                    callback = DEFUN [
                      (SET vim.o.colorcolumn old_colorcolumn)
                      # return true = delete autocommand
                      (RETURN true)
                    ];
                  })
                ])
              ))
              (IF (APPLY OR (map (EQ filetype) [ "markdown" "mail" ])) (
                (SET (IDX vim.bo buf).textwidth 72)
              ))
            ]);
          BufWinEnter = { buf, ... }:
            LET (vim.filetype.match { inherit buf; }) (filetype: [
              (CALL (PROP vim.cmd "folddoc") "foldopen!")
              (IF (EQ filetype "gitcommit") (
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
              )))
            ]);
        }
      ))
    ]);
    extraPlugins = map (x: x.plugin or x) plugins;
  };
}
