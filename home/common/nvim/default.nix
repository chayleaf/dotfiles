{ config, pkgs, lib, ... }:
{
  imports = [ ../options.nix ];
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
  programs.neovim = let
    # a cursed DSL
    identLines = lines: builtins.concatStringsSep "\n" (map (x: "  ${x}") lines);
    ident = code: identLines (lib.splitString "\n" code);
    # probably not the best heuristics, but good enough to make the output readable
    wrapSafe = s: (builtins.match "^[-\"a-zA-Z0-9_.()]*$" s) != null;
    wrapExpr = s: if wrapSafe s then s else "(${s})";
    keySafe = s: (builtins.match "^[a-zA-Z_][_a-zA-Z0-9]*$" s) != null;
    wrapKey = scope: s: if keySafe s then s else "[${compileExpr scope s}]";
    compileFunc' = argn: sc@{sname,scope}: id: func:
      (if builtins.isFunction func
      then
      (compileFunc'
          (argn + 1)
          sc
          id
          (func (let
            args = builtins.functionArgs func;
            rawVar = var "${sname}_${id}_arg${builtins.toString (scope + argn)}";
          in if args == {}
            then rawVar
            else builtins.mapAttrs (k: v: prop rawVar k) args
          )))
      else ''
        function ${id}(${builtins.concatStringsSep ", " (builtins.genList (n: "${sname}_${id}_arg${builtins.toString (scope + n)}") argn)})
        ${ident (compileStmt {inherit sname;scope = scope + argn;} func)}
        end'');
    compileFunc = compileFunc' 0;
    compileExpr = sc: func: (
      if builtins.isString func then
        if lib.hasInfix "\n" func then ''
        [[
        ${ident func}
        ]]'' else "\"${lib.escape ["\\" "\""] func}\""
      else if builtins.isInt func then builtins.toString func
      else if builtins.isFloat func then builtins.toString func
      else if builtins.isBool func then (if func then "true" else "false")
      else if builtins.isNull func then "nil"
      else if builtins.isPath func then compileExpr sc (builtins.toString func)
      else if builtins.isFunction func then let
        info = if builtins.functionArgs func == {} then (func "GET_INFO") else null; in
        if builtins.isAttrs info && info?value
          then info.value
          else (compileFunc sc "" func)
      else if builtins.isList func then ''
        {
        ${ident (builtins.concatStringsSep "\n" (map (x: (compileExpr sc x) + ";" ) func))}
        }''
      else if builtins.isAttrs func && !(func?__kind) then ''
        {
        ${ident (builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${wrapKey sc k} = ${compileExpr sc v};") func))}
        }''
      else if func.__kind == "var" then
        "${func._name}"
      else if func.__kind == "op2" then
        builtins.concatStringsSep func.op (map (x: wrapExpr (compileExpr sc x)) func.args)
      else if func.__kind == "defun" then
        (compileFunc sc (if func?id then func.id else "") func.func)
      else if func.__kind == "prop" then
        "${wrapExpr (compileExpr sc func.expr)}.${func.name}"
      else if func.__kind == "call" then
        "${wrapExpr (compileExpr sc func.func)}(${builtins.concatStringsSep ", " (map (compileExpr sc) (if builtins.isList func.args then func.args else [func.args]))})"
      else if func.__kind == "mcall" then
        "${wrapExpr (compileExpr sc func.val)}:${func.name}(${builtins.concatStringsSep ", " (map (compileExpr sc) (if builtins.isList func.args then func.args else [func.args]))})"
      else if func.__kind == "tableAttr" then
        "${wrapExpr (compileExpr sc func.table)}[${compileExpr sc func.key}]"
      else null
    );
    compileStmt = sc@{sname,scope}: func: (
      if builtins.isList func then builtins.concatStringsSep "\n" (map (compileStmt sc) func)
      else if builtins.isAttrs func && (func?__kind) then (
        if func.__kind == "assign" then
          "${compileExpr sc func.expr} = ${compileExpr sc func.val}"
        else if func.__kind == "bind" then
          "local ${func.name} = ${compileExpr sc func.val}"
        else if func.__kind == "let" then ''
          ${builtins.concatStringsSep "\n" (lib.imap0 (n: val:
          "local ${sname}_var${builtins.toString (scope + n)} = ${
            compileExpr sc val
          }") func.vals)}
          ${let vals = func.vals; origScope = scope; apply = { scope, func }: if scope == (origScope + (builtins.length vals)) then func else apply {
              scope = scope + 1;
              func = func (raw "${sname}_var${builtins.toString scope}");
            }; in 
            compileStmt {inherit sname;scope = scope + (builtins.length func.vals);} (apply { inherit scope; inherit (func) func; })
          }''
        else if func.__kind == "letrec" then ''
          ${builtins.concatStringsSep "\n" (lib.imap0 (n: val:
          "local ${sname}_var${builtins.toString (scope + n)} = ${
            let vals = func.vals; origScope = scope; apply = { scope, func }: if scope == (origScope + (builtins.length vals)) then func else apply {
              scope = scope + 1;
              func = func (raw "${sname}_var${builtins.toString scope}");
            }; in
            compileExpr {inherit sname;scope = scope + (builtins.length func.vals);} (apply { inherit scope; func = val; })
          }") func.vals)}
          ${let vals = func.vals; origScope = scope; apply = { scope, func }: if scope == (origScope + (builtins.length vals)) then func else apply {
              scope = scope + 1;
              func = func (raw "${sname}_var${builtins.toString scope}");
            }; in 
            compileStmt {inherit sname;scope = scope + (builtins.length func.vals);} (apply { inherit scope; inherit (func) func; })
          }''
        else if func.__kind == "for" then let
          varNames = builtins.genList (n: "${sname}_var${builtins.toString (scope + n)}") func.n;
          scope' = { inherit sname; scope = scope + 1; };
          in ''
            for ${builtins.concatStringsSep "," varNames} in ${compileExpr scope' func.expr} do
            ${
              let argn = func.n; origScope = scope; apply = { scope, func }: if scope == (origScope + argn) then func else apply {
                scope = scope + 1;
                func = func (raw "${sname}_var${builtins.toString scope}");
              }; in 
              ident (compileStmt scope' (apply { inherit scope; func = func.body; }))
            }
            end''
        else if func.__kind == "return" then
          "return ${compileExpr sc func.expr}"
        else if func.__kind == "if" then
          (lib.removeSuffix "else" ((builtins.concatStringsSep "" (map
            (cond: ''
              if ${compileExpr sc (builtins.elemAt cond 0)} then
              ${ident (compileStmt sc (builtins.elemAt cond 1))}
              else'')
            func.conds))
          + (if func.fallback != null then "\n${ident (compileStmt sc func.fallback)}\n" else ""))) + "end"
        else compileExpr sc func
      ) else compileExpr sc func
    );
    compile = sname: compileStmt {inherit sname;scope=1;};
    var = name: { __kind = "var"; _name = name; };
    raw = var;
    prop = expr: name: { __kind = "prop"; inherit expr name; };
    call = func: args: { __kind = "call"; inherit func args; };
    mcall = val: name: args: { __kind = "mcall"; inherit val name args; };
    setup = plugin: opts: call (prop plugin "setup") [ opts ];
    require = name: call (var "require") [ name ];
    set = expr: val: { __kind = "assign"; inherit expr val; };
    op2 = op: args:
      if builtins.isList args then { __kind = "op2"; inherit op args; }
      else (secondArg: { __kind = "op2"; inherit op; args = [ args secondArg ]; })
    ;
    eq = op2 "==";
    # forin = n: expr: body: { __kind = "for"; inherit n expr body; };
    # gt = op2 ">";
    # ge = op2 ">=";
    # ne = op2 "~=";
    # and = op2 "and";
    # or = op2 "or";
    return = expr: { __kind = "return"; inherit expr; };
    defun = func: { __kind = "defun"; inherit func; };
    ifelse = conds: fallback: { __kind = "if"; inherit fallback; conds = if builtins.isList (builtins.elemAt conds 0) then conds else [conds]; };
    # ifnoelse = conds: ifelse conds null;
    tableAttr = table: key: { __kind = "tableAttr"; inherit table key; };
    bind = vals: func: if builtins.isList vals then { __kind = "let"; inherit vals func; } else bind [ vals ] func;
    bindrec = vals: func: if builtins.isList vals then { __kind = "letrec"; inherit vals func; } else bindrec [ vals ] func;
    defs = pkgs.callPackage ./vim-opts.nix { inherit raw call; };
  in with defs; let
    # bind' = name: val: { __kind = "bind"; inherit name val; };
    # vimfn = name: call (raw "vim.fn.${name}");
    vimcmd = name: call (raw "vim.cmd.${name}");
    keymapSetSingle = opts@{
      mode,
      lhs,
      rhs,
      noremap ? true,
      silent ? true,
      ...
    }: let
      opts''' = opts // { inherit noremap silent; };
      opts' = lib.filterAttrs (k: v:
        k != "keys" && k != "mode" && k != "lhs" && k != "rhs" && k != "desc"
        # defaults to false
        && ((k != "silent" && k != "noremap") || (builtins.isBool v && v))) opts''';
      in vim.keymap.set [ mode lhs rhs opts' ];
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
        (call (prop (require "which-key") "register") [(lib.mapAttrs (k: v: [v.rhs v.desc]) keys) opts'])
      ];
    keymapSetN = args: keymapSetSingle (args // { mode = "n"; });
    keymapSetV = args: keymapSetSingle (args // { mode = "v"; });
    keymapSetNs = args: keymapSetMulti (args // { mode = "n"; });
    kmSetNs = keys: keymapSetNs { inherit keys; };
  in {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim-unwrapped;
    extraPackages = with pkgs; [
      rust-analyzer
      nodePackages_latest.bash-language-server shellcheck
      nodePackages_latest.typescript-language-server
      nodePackages_latest.svelte-language-server
      clang-tools
      nodePackages_latest.vscode-langservers-extracted
      nil
      marksman
      taplo
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
    extraLuaConfig = (compile "main" [
      (set vim.g.vimsyn_embed "l")
      (vim.api.nvim_set_hl [ 0 "NormalFloat" {
        bg = "NONE";
      }])
      (bind (vim.api.nvim_create_augroup [ "nvimrc" { clear = true; } ]) (group:
        map (au: let au' = lib.filterAttrs (k: v: k != "event") au;
          in vim.api.nvim_create_autocmd [ au.event ({
            inherit group;
          } // au') ]
        ) [
          { event = "FileType";
            pattern = ["markdown" "gitcommit"];
            callback = defun (set vim.o.colorcolumn 73); }
          { event = "FileType";
            pattern = ["markdown"];
            callback = defun (set vim.o.textwidth 72); }
          { event = "BufReadPre";
            inherit group;
            callback = defun (set vim.o.foldmethod "syntax"); }
          { event = "BufWinEnter";
            inherit group;
            callback = { buf, ... }:
              (bind (vim.filetype.match { inherit buf; }) (filetype: [
                (vimcmd "folddoc" [ "foldopen!" ])
                (ifelse [(eq filetype "gitcommit") [
                  (vim.cmd {
                    cmd = "normal";
                    bang = true;
                    args = [ "gg" ];
                  })
                ]]
                  (vim.cmd {
                    cmd = "normal";
                    bang = true;
                    args = [ "g`\"" ];
                  })
                )
              ])); }
            ])) # END
    ]);
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; map (x: if x?config && x?plugin then { type = "lua"; } // x else x) [
      vim-svelte
      # TODO remove on next nvim update (0.8.3/0.9)
      vim-nix
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
        config = compile "vscode_nvim" (setup (require "vscode") {
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
          }); }
        # ''; }
      { plugin = nvim-web-devicons;
        config = compile "nvim_web_devicons" (setup (require "nvim-web-devicons") {}); }
      { plugin = nvim-tree-lua;
        config = compile "nvim_tree_lua" [
          (set vim.g.loaded_netrw 1)
          (set vim.g.loaded_netrwPlugin 1)
          (set vim.opt.termguicolors true)
          (setup (require "nvim-tree") {}) # :help nvim-tree-setup
          (keymapSetN {
            lhs = "<C-N>";
            rhs = prop (require "nvim-tree.api") "tree.toggle";
            desc = "Toggle NvimTree";
          })
        ]; }
      vim-sleuth
      luasnip
      { plugin = nvim-cmp;
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
        in compile "nvim_cmp" [(bind (require "cmp") (cmp:
          (setup cmp {
            snippet = {
              expand = args: (call (prop (require "luasnip") "lsp_expand") (prop args "body"));
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
              format = _: vim_item: [
                (set
                  (prop vim_item "kind")
                  (string.format (let kind = prop vim_item "kind"; in [
                    "%s %s"
                    (tableAttr (require "lspkind") kind)
                    kind
                  ])))
                (return vim_item)
              ];
            };
            mapping = {
              "<C-p>" = call (prop cmp "mapping.select_prev_item") [];
              "<C-n>" = call (prop cmp "mapping.select_next_item") [];
              "<C-space>" = call (prop cmp "mapping.complete") [];
              "<C-e>" = call (prop cmp "mapping.close") [];
              "<cr>" = call (prop cmp "mapping.confirm") {
                behavior = prop cmp "ConfirmBehavior.Replace";
                select = false;
              };
              "<tab>" = call (prop cmp "mapping") [(fallback:
                (ifelse [
                  [(call (prop cmp "visible") [])
                    # then
                    (call (prop cmp "select_next_item") [])]
                  [(call (prop (require "luasnip") "expand_or_jumpable") [])
                    # then
                    (vim.api.nvim_feedkeys [
                      (vim.api.nvim_replace_termcodes [ "<Plug>luasnip-expand-or-jump" true true true ])
                      ""
                      false
                    ])
                  ]]
                    # else
                    (call fallback [])
                ))
                [ "i" "s" ]
              ];
              "<S-tab>" = call (prop cmp "mapping") [(fallback:
                (ifelse [
                  [(call (prop cmp "visible" ) [])
                    # then
                    (call (prop cmp "select_prev_item") [])]
                  [(call (prop (require "luasnip") "jumpable") [ (-1) ])
                    # then
                    (vim.api.nvim_feedkeys [
                      (vim.api.nvim_replace_termcodes [ "<Plug>luasnip-jump-prev" true true true ])
                      ""
                      false
                    ])
                  ]]
                    # else
                    (call fallback [])
                ))
                [ "i" "s" ]
              ];
            };
            sources = call (prop cmp "config.sources") [[
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
            ]];
          })
        ))]; }
      lspkind-nvim
      cmp_luasnip
      cmp-nvim-lsp
      { plugin = nvim-autopairs;
        config = compile "nvim_autopairs" (bind (require "nvim-autopairs.completion.cmp") (cmp_autopairs: [
          (setup (require "nvim-autopairs") {
            disable_filetype = [ "TelescopePrompt" "vim" ];
          })
          (mcall (prop (require "cmp") "event") "on" [
            "confirm_done"
            (call (prop cmp_autopairs "on_confirm_done") [])
          ])
        ])); }
      { plugin = comment-nvim;
        config = compile "comment_nvim" [
          (setup (require "Comment") {})
          (keymapSetN {
            lhs = "<space>/";
            rhs = (prop (require "Comment.api") "toggle.linewise.current");
            desc = "Comment current line";
          })
          (keymapSetV {
            lhs = "<space>/";
            rhs = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>";
            desc = "Comment current line";
          })
        ]; }
      { plugin = nvim-lspconfig;
        config = compile "nvim_lspconfig" (let setupLsp = lsp: setup (prop (require "lspconfig") lsp); in [
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
          (bind [
            # LET on_attach
            (client: bufnr: ([
              # Enable completion triggered by <c-x><c-o>
              (vim.api.nvim_buf_set_option [ bufnr "omnifunc" "v:lua.vim.lsp.omnifunc" ])
              # Mappings.
              # See `:help vim.lsp.*` for documentation on any of the below functions
              (kmSetNs {
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
                  rhs = (defun (print [
                    (vim.inspect [(vim.lsp.buf.list_workspace_folders [])])
                  ]));
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
                  rhs = (defun (vim.lsp.buf.format {async = true;}));
                  desc = "Formats a buffer."; };
              })
            ]))
            # LET rust_settings
            { rust-analyzer = {
              assist.emitMustUse = true;
              cargo.buildScripts.enable = true;
              check.command = "clippy";
              procMacro.enable = true;
            }; }
            # LET capabilities
            (vim.tbl_extend [
              "keep"
              (vim.lsp.protocol.make_client_capabilities [])
              (call (prop (require "cmp_nvim_lsp") "default_capabilities") [])
            ])
          # BEGIN
          ] (on_attach: rust_settings: capabilities: [
            (bindrec
            # LETREC on_attach_rust
            (on_attach_rust: client: bufnr: [
              (vim.api.nvim_create_user_command ["RustAndroid" (opts: [
                (setupLsp "rust_analyzer" {
                  on_attach = on_attach_rust;
                  inherit capabilities;
                  settings = vim.tbl_deep_extend [
                    "keep"
                    { rust-analyzer.cargo.target = "x86_64-linux-android"; }
                    rust_settings
                  ];
                })
              ]) {}])
              (call on_attach [client bufnr])
            ])
            # BEGIN
            (let lsp = { name, settings ? {} }: setupLsp name {
              inherit on_attach capabilities settings;
            }; in (on_attach_rust: [
              (vim.lsp.set_log_level "debug")
            ] ++ [
              (map lsp [
                # see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
                { name = "bashls"; }
                { name = "clangd"; }
                # https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
                { name = "pylsp"; settings = {
                  pylsp.plugins.pylsp_mypy.enabled = true;
                }; }
                { name = "svelte"; }
                { name = "html"; }
                { name = "cssls"; }
                { name = "tsserver"; }
                { name = "jsonls"; }
                { name = "nil_ls"; }
                { name = "taplo"; }
                { name = "marksman"; }
              ])
              (setupLsp "rust_analyzer" {
                on_attach = on_attach_rust;
                settings = rust_settings;
                inherit capabilities;
              })
            ]))) # END
          ])) # END
        ]); }
      { plugin = which-key-nvim;
        config = compile "which_key_nvim" [
          (set vim.o.timeout true)
          (set vim.o.timeoutlen 500)
          (setup (require "which-key") {})
        ]; }
    ];
  };
}
