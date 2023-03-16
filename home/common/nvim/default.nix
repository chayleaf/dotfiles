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

  # welcome to my cursed DSL
  programs.neovim = let
    # add a single ident level to code
    identLines = lines: builtins.concatStringsSep "\n" (map (x: "  ${x}") lines);
    ident = code: identLines (lib.splitString "\n" code);

    # convert list into pairs
    pairsv = ret: list: key: if list == [] then {
        list = ret;
        leftover = key;
      } else pairsk (ret ++ [[key (builtins.head list)]]) (builtins.tail list);
    pairsk = ret: list: if list == [] then {
        list = ret;
        leftover = null;
      } else pairsv ret (builtins.tail list) (builtins.head list);

    # list end
    end = list: builtins.elemAt list (builtins.length list - 1);
    # pop list end
    pop = list: lib.take (builtins.length list - 1) list;

    luaType = val:
      if builtins.isAttrs val && val?__kind then (
        if val?_type then val._type
        # can't know the type of arbitrary expressions!
        else null
      ) else if builtins.isList val || builtins.isAttrs val then "table"
      else if builtins.isPath val || builtins.isString val then "string"
      else if builtins.isInt val || builtins.isFloat val then "number"
      else if builtins.isNull val then "nil"
      else if builtins.isFunction val then let info = getInfo val; in (
        if info != null && info?_expr then luaType info._expr
        else if info != null && info?_stmt then luaType info._stmt
        else "function"
      ) else if builtins.isBool val then "boolean"
      else null;

    # vararg system
    getInfo = func: if builtins.isFunction func && builtins.functionArgs func == {} then (
      let ret = builtins.tryEval (func {__GET_INFO = true;}); in if ret.success then ret.value else null
    ) else null;
    isGetInfo = arg: arg == { __GET_INFO = true; };
    argsSink = key: args: finally: arg:
      if isGetInfo arg then
        {${key} = finally args;}
      else if builtins.isAttrs arg && arg?__kind && arg.__kind == "unroll" then
        {${key} = finally (args ++ arg.list);}
      else
        argsSink key (args ++ [arg]) finally;

    # The following functions may take state: moduleName and scope
    # scope is how many variables are currently in scope
    # the count is used for generating new variable names

    pushScope = n: { moduleName, scope }: { inherit moduleName; scope = scope + n; };
    pushScope1 = pushScope 1;

    # wrap an expression in parentheses if necessary
    # probably not the best heuristics, but good enough to make the output readable
    wrapSafe = s: (builtins.match "^[-\"a-zA-Z0-9_.()]*$" s) != null;
    wrapExpr = s: if wrapSafe s then s else "(${s})";

    # Same, but for table keys
    keySafe = s: (builtins.match "^[a-zA-Z_][_a-zA-Z0-9]*$" s) != null;
    wrapKey = scope: s: if keySafe s then s else "[${compileExpr scope s}]";

    applyVars' = origScope: count: prefix: let self = (scope: func: argc:
      let info = getInfo func; in
      if info != null && info?_expr then self scope info._expr argc
      else if info != null && info?_stmt then self scope info._stmt argc
      else if count != null && scope == (origScope + count) then { result = func; }
      else if count == null && !builtins.isFunction func then { result = func; inherit argc; }
      else self (scope + 1) (let
        args = builtins.functionArgs func;
        name = "${prefix}${builtins.toString scope}"; in
          if args == {} then func (RAW name)
          else func (builtins.mapAttrs (k: v: RAW "${name}.${k}") args)) (argc + 1)
    ); in self;
    applyVars = count: prefix: scope: func: applyVars' scope count prefix scope func 0;

    compileFunc = state@{moduleName, scope}: id: expr:
    let
      res = applyVars null "${moduleName}_${id}_arg" scope expr;
      argc = res.argc;
      func = res.result;
      header = if id == "" then "function" else "local function ${id}";
    in ''
      ${header}(${builtins.concatStringsSep ", " (builtins.genList (n: "${moduleName}_${id}_arg${builtins.toString (scope + n)}") argc)})
      ${ident (compileStmt (pushScope argc state) func)}
      end'';

    compileExpr = state: func: (
      if builtins.isString func then
        if lib.hasInfix "\n" func then ''
        [[
        ${ident func}
        ]]'' else "\"${lib.escape ["\\" "\""] func}\""
      else if builtins.isInt func then builtins.toString func
      else if builtins.isFloat func then builtins.toString func
      else if builtins.isBool func then (if func then "true" else "false")
      else if builtins.isNull func then "nil"
      else if builtins.isPath func then compileExpr state (builtins.toString func)
      else if builtins.isFunction func then let
        info = getInfo func; in
        if info != null && info?_name then
          info._name
        else if info != null && info?_expr then
          compileExpr state info._expr
        else if info != null && info?_stmt then
          assert false; null
        else (compileFunc state "" func)
      else if builtins.isList func then ''
        {
        ${ident (builtins.concatStringsSep "\n" (map (x: (compileExpr state x) + ";" ) func))}
        }''
      else if builtins.isAttrs func && func?_expr then compileExpr state func._expr
      else if builtins.isAttrs func && !(func?__kind) then ''
        {
        ${ident (builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${wrapKey state k} = ${compileExpr state v};") func))}
        }''
      else if func.__kind == "var" then
        "${func._name}"
      else if func.__kind == "op2" then
        builtins.concatStringsSep " ${func.op} " (map (x: wrapExpr (compileExpr state x)) func.args)
      else if func.__kind == "defun" then
        (compileFunc state (if func?id then func.id else "") func.func)
      else if func.__kind == "prop" then
        assert lib.assertMsg (luaType func.expr == null || luaType func.expr == "table") "Unable to get property ${func.name} of a ${luaType func.expr}!";
        "${wrapExpr (compileExpr state func.expr)}.${func.name}"
      else if func.__kind == "call" then
        let args = func._args; in
        assert lib.assertMsg
          ((!(func._func?_minArity) || (builtins.length args) >= func._func._minArity) && (!(func._func?_maxArity) || (builtins.length args) <= func._func._maxArity))
          "error: wrong function arity for ${compileExpr state func._func}! expected at least ${builtins.toString func._func._minArity}; found ${builtins.toString (builtins.length args)}";
        "${wrapExpr (compileExpr state func._func)}(${builtins.concatStringsSep ", " (map (compileExpr state) args)})"
      else if func.__kind == "mcall" then
        "${wrapExpr (compileExpr state func.val)}:${func.name}(${builtins.concatStringsSep ", " (map (compileExpr state) func.args)})"
      else if func.__kind == "tableAttr" then
        assert lib.assertMsg (luaType func.table == null || luaType func.table == "table") "Unable to get table value ${compileExpr state func.key} of a ${luaType func.table} ${compileExpr state func.table}!";
        "${wrapExpr (compileExpr state func.table)}[${compileExpr state func.key}]"
      else assert lib.assertMsg false "Invalid kind ${func.__kind}"; null
    );

    compileStmt = state@{moduleName,scope}: func: (
      if builtins.isList func then builtins.concatStringsSep "\n" (map (compileStmt state) func)
      else if builtins.isAttrs func && func?_stmt then compileStmt state func._stmt
      else if builtins.isAttrs func && (func?__kind) then (
        if func.__kind == "assign" then
          assert lib.assertMsg
            (luaType func.expr == null || luaType func.val == null || luaType func.val == func.expr._type)
            "error: setting ${compileExpr state func.expr} to wrong type. It should be ${luaType func.expr} but is ${luaType func.val}";
          "${compileExpr state func.expr} = ${compileExpr state func.val}"
        else if func.__kind == "bind" then
          "local ${func.name} = ${compileExpr state func.val}"
        else if func.__kind == "let" then ''
          ${builtins.concatStringsSep "\n" (lib.imap0 (n: val:
          "local ${moduleName}_var${builtins.toString (scope + n)} = ${
            compileExpr state val
          }") func.vals)}
          ${
            let res = applyVars (builtins.length func.vals) "${moduleName}_var" scope func.func; in
            compileStmt (pushScope (builtins.length func.vals) state) res.result
          }''
        else if func.__kind == "letrec" then let argc = builtins.length func.vals; in ''
          ${builtins.concatStringsSep "\n" (lib.imap0 (n: val:
          "local ${moduleName}_var${builtins.toString (scope + n)} = ${
            let res = applyVars argc "${moduleName}_var" scope val; in
            compileExpr (pushScope argc state) res.result
          }") func.vals)}
          ${
            let res = applyVars argc "${moduleName}_var" scope func.func; in
            compileStmt (pushScope (builtins.length func.vals) state) res.result
          }''
        else if func.__kind == "for" then let
          res = applyVars null "${moduleName}_var" scope func.body;
          varNames = builtins.genList (n: "${moduleName}_var${builtins.toString (scope + n)}") res.argc;
          in ''
            for ${builtins.concatStringsSep "," varNames} in ${compileExpr scope func.expr} do
            ${
              ident (compileStmt (pushScope1 state) res.result)
            }
            end''
        else if func.__kind == "return" then
          "return ${compileExpr state func.expr}"
        else if func.__kind == "if" then
          (lib.removeSuffix "else" ((builtins.concatStringsSep "" (map
            (cond: ''
              if ${compileExpr state (builtins.elemAt cond 0)} then
              ${ident (compileStmt state (builtins.elemAt cond 1))}
              else'')
            func.conds))
          + (if func.fallback != null then "\n${ident (compileStmt state func.fallback)}\n" else ""))) + "end"
        else compileExpr state func
      ) else if builtins.isFunction func then (let
        info = getInfo func; in
        if info != null && info?_stmt then compileStmt state info._stmt
        else compileExpr state func
      ) else compileExpr state func
    );

    # compile a module
    compile = moduleName: input: (compileStmt { inherit moduleName; scope = 1; } input) + "\n";

    # pass some raw code to lua directly
    VAR = name: { __kind = "var"; _name = name; };
    RAW = VAR;

    # Access a property
    # Corresponding lua code: table.property
    # expr -> identifier -> expr
    PROP = expr: name: { __kind = "prop"; inherit expr name; };

    # Escape a list so it can be passed to vararg functions
    UNROLL = list: { __kind = "unroll"; inherit list; };

    # Apply a list of arguments to a function/operator (probably more useful than the above)
    APPLY = func: list: func (UNROLL list);

    # Call a function
    # Useful if you need to call a zero argument function, or if you need to handle some weird metatable stuff
    # corresponding lua code: someFunc()
    # expr -> arg1 -> ... -> argN -> expr
    CALL = func: argsSink "_expr" [] (args: { __kind = "call"; _func = func; _args = args; });

    # Call a method
    # corresponding lua code: someTable:someFunc()
    # expr -> identifier -> arg1 -> ... -> argN -> expr
    MCALL = val: name: argsSink "_expr" [] (args: { __kind = "mcall"; inherit val name args; });

    # corresponding lua code: =
    # expr -> expr -> stmt
    SET = expr: val: { __kind = "assign"; inherit expr val; };

    # opName -> [exprs] -> expr | opName -> expr1 -> ... -> exprN -> expr
    OP2 = op: argsSink "_expr" [] (args: { __kind = "op2"; inherit op args; });

    # The following all have the signature
    # expr1 -> ... -> exprN -> expr
    EQ = OP2 "==";
    # GT = OP2 ">";
    # GE = OP2 ">=";
    # NE = OP2 "~=";
    # AND = OP2 "and";
    OR = OP2 "or";

    # Corresponding lua code: for ... in ...
    # argc -> expr -> (expr1 -> ... -> exprN -> stmts) -> stmts
    # FORIN = expr: body: { __kind = "for"; inherit expr body; };

    # Issues a return statement
    # Corresponding lua code: return
    # expr -> stmt
    RETURN = expr: { __kind = "return"; inherit expr; };

    # Creates a zero argument function with user-provided statements
    # stmts -> expr
    DEFUN = func: { __kind = "defun"; inherit func; };

    # Corresponding lua code: if then (else?)
    # [[cond expr]] -> fallbackExpr? -> stmts
    IFELSE' = conds: fallback: { __kind = "if"; inherit fallback; conds = if builtins.isList (builtins.elemAt conds 0) then conds else [conds]; };

    # Corresponding lua code: if then (else?)
    # (expr -> stmts ->)* (fallback expr ->)? stmts
    IF = argsSink "_stmt" [] (args:
      let pairs = pairsk [] args; in
      if pairs.leftover == null && builtins.length pairs.list > 1 && builtins.elemAt (end pairs.list) 0 == ELSE
      then IFELSE' (pop pairs.list) (builtins.elemAt (end pairs.list) 1)
      else IFELSE' pairs.list pairs.leftover
    );

    # Signifies the fallback branch in IF. May only be the last branch.
    # Note that you may also omit it and just include the last branch without a preceding condition.
    ELSE = true;

    # Corresponding lua code: table[key]
    # table -> key -> expr
    ATTR = table: key: { __kind = "tableAttr"; inherit table key; };

    # Directly creates a local varible with your chosen name
    # But why would you use this???
    # bind' = name: val: { __kind = "bind"; inherit name val; };

    # Creates variables and passes them to the function
    # Corresponding lua code: local ... = ...
    # expr1 -> (expr -> stmt) -> stmt | [expr] -> (expr1 -> ... -> exprN -> stmt) -> stmt
    LET = vals: func: if builtins.isList vals then { __kind = "let"; inherit vals func; } else LET [ vals ] func;

    # Creates variables and passes them to the function as well as variable binding code
    # Corresponding lua code: local ... = ...
    # (expr1 -> expr) -> (expr1 -> stmt) -> stmt | [(expr1 -> ... -> exprN -> expr)] -> (expr1 -> ... -> exprN -> stmt) -> stmt
    LETREC = vals: func: if builtins.isList vals then { __kind = "letrec"; inherit vals func; } else LETREC [ vals ] func;

    # "type definitions" for neovim
    defs = pkgs.callPackage ./vim-opts.nix { inherit RAW CALL isGetInfo compileExpr; inherit (config.programs.neovim) plugins; };

    reqbindGen = names: func:
      if names == [] then func
      else result: reqbindGen (builtins.tail names) (func (defs._reqbind (builtins.head names) result._name));

    # bind a value to a require
    REQBIND = name: func:
      if builtins.isList name
      then LET (map defs.require name) (reqbindGen name func)
      else LET [ (defs.require name) ] (result: func (defs._reqbind name result._name));
  in with defs; let
    vimcmd = name: CALL (RAW "vim.cmd.${name}");
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
        (which-key.register (lib.mapAttrs (k: v: [v.rhs v.desc]) keys) opts')
      ];
    keymapSetNs = args: keymapSetMulti (args // { mode = "n"; });
    kmSetNs = keys: keymapSetNs { inherit keys; };
    keymapSetVs = args: keymapSetMulti (args // { mode = "v"; });
    kmSetVs = keys: keymapSetVs { inherit keys; };

    which-key = REQ "which-key";
    luasnip = REQ "luasnip";
    cmp = REQ "cmp";
  in {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim-unwrapped;
    extraPackages = with pkgs; [
      rust-analyzer
      nodePackages_latest.bash-language-server shellcheck
      nodePackages_latest.typescript-language-server
      nodePackages_latest.svelte-language-server
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

    extraLuaConfig = (compile "main" [
      (SET (vimg "vimsyn_embed") "l")
      (LET (vim.api.nvim_create_augroup "nvimrc" { clear = true; }) (group:
        lib.mapAttrsToList (k: v: vim.api.nvim_create_autocmd k { inherit group; callback = v; }) {
          BufReadPre = DEFUN (SET vim.o.foldmethod "syntax");
          BufEnter = { buf, ... }:
            (LET (vim.filetype.match { inherit buf; }) (filetype: [
              (IF (APPLY OR (map (EQ filetype) [ "gitcommit" "markdown" ])) (LET vim.o.colorcolumn (old_colorcolumn: [
                (SET vim.o.colorcolumn "73")
                (vim.api.nvim_create_autocmd "BufLeave" {
                  callback = DEFUN [
                    (SET vim.o.colorcolumn old_colorcolumn)
                    # return true = delete autocommand
                    (RETURN true)
                  ];
                })
              ])))
              (IF (EQ filetype "markdown") (LET vim.o.textwidth (old_textwidth: [
                (SET vim.o.textwidth 72)
                (vim.api.nvim_create_autocmd "BufLeave" {
                  callback = DEFUN [
                    (SET vim.o.textwidth old_textwidth)
                    (RETURN true)
                  ];
                })
              ])))
            ]));
          BufWinEnter = { buf, ... }:
            (LET (vim.filetype.match { inherit buf; }) (filetype: [
              (vimcmd "folddoc" "foldopen!")
              (IF (EQ filetype "gitcommit")
                (CALL vim.cmd {
                  cmd = "normal";
                  bang = true;
                  args = [ "gg" ];
                })
              ELSE
                (CALL vim.cmd {
                  cmd = "normal";
                  bang = true;
                  args = [ "g`\"" ];
                })
              )
            ]));
        }
      ))
    ]);
    plugins = let ps = pkgs.vimPlugins; in map (x: if x?config && x?plugin then { type = "lua"; } // x else x) [
      ps.vim-svelte
      # TODO remove on next nvim update (0.8.3/0.9)
      ps.vim-nix
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
        config = compile "vscode_nvim" [
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
        config = compile "nvim_web_devicons" ((REQ "nvim-web-devicons").setup {}); }
      { plugin = ps.nvim-tree-lua;
        config = compile "nvim_tree_lua" (REQBIND ["nvim-tree" "nvim-tree.api"] (nvim-tree: nvim-tree-api: [
          (SET (vimg "loaded_netrw") 1)
          (SET (vimg "loaded_netrwPlugin") 1)
          (SET vim.o.termguicolors true)
          (nvim-tree.setup {}) # :help nvim-tree-setup
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
        in compile "nvim_cmp" (REQBIND [ "cmp" "lspkind" ] (cmp: lspkind:
          # call is required because cmp.setup is a table
          (CALL cmp.setup {
            snippet = {
              expand = { body, ... }: luasnip.lsp_expand body {};
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
              format = _: vim_item: let kind = PROP vim_item "kind"; in [
                (SET kind (string.format "%s %s" (ATTR lspkind kind) kind))
                (RETURN vim_item)
              ];
            };
            mapping = {
              "<C-p>" = cmp.mapping.select_prev_item {};
              "<C-n>" = cmp.mapping.select_next_item {};
              "<C-space>" = cmp.mapping.complete {};
              "<C-e>" = cmp.mapping.close {};
              "<cr>" = cmp.mapping.confirm {
                behavior = cmp.ConfirmBehavior.Replace;
                select = false;
              };
              "<tab>" = CALL cmp.mapping (fallback:
                (IF
                  (CALL cmp.visible)
                    (CALL cmp.select_next_item)
                  (CALL luasnip.expand_or_jumpable)
                    (vim.api.nvim_feedkeys
                      (vim.api.nvim_replace_termcodes "<Plug>luasnip-expand-or-jump" true true true)
                      ""
                      false)
                  ELSE
                    (CALL fallback)))
                [ "i" "s" ];
              "<S-tab>" = CALL cmp.mapping (fallback:
                (IF
                  (CALL cmp.visible)
                    (CALL cmp.select_prev_item)
                  (luasnip.jumpable (-1))
                    (vim.api.nvim_feedkeys
                      (vim.api.nvim_replace_termcodes "<Plug>luasnip-jump-prev" true true true)
                      ""
                      false)
                  ELSE
                    (CALL fallback)))
                [ "i" "s" ];
            };
            sources = cmp.config.sources [
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
            ];
          })
        )); }
      ps.lspkind-nvim
      ps.cmp_luasnip
      ps.cmp-nvim-lsp
      { plugin = ps.nvim-autopairs;
        config = compile "nvim_autopairs" (REQBIND ["nvim-autopairs.completion.cmp" "nvim-autopairs"] (cmp-autopairs: nvim-autopairs: [
          (nvim-autopairs.setup {
            disable_filetype = [ "TelescopePrompt" "vim" ];
          })
          (MCALL cmp.event "on" "confirm_done" (cmp-autopairs.on_confirm_done {}))
        ])); }
      { plugin = ps.comment-nvim;
        config = compile "comment_nvim" [
          ((REQ "Comment").setup {})
          (kmSetNs {
            "<space>/" = {
              rhs = PROP (REQ "Comment.api").toggle "linewise.current";
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
        config = compile "nvim_lspconfig" (
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
          (LET [
            # LET on_attach
            (client: bufnr: [
              # Enable completion triggered by <c-x><c-o>
              (vim.api.nvim_buf_set_option bufnr "omnifunc" "v:lua.vim.lsp.omnifunc")
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
                  rhs = DEFUN (print (CALL vim.inspect (CALL vim.lsp.buf.list_workspace_folders)));
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
                  rhs = (DEFUN (vim.lsp.buf.format {async = true;}));
                  desc = "Formats a buffer."; };
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
              ((REQ "cmp_nvim_lsp").default_capabilities {})
              (CALL vim.lsp.protocol.make_client_capabilities))
          # BEGIN
          ] (on_attach: rust_settings: capabilities: [
            (LETREC
            # LETREC on_attach_rust
            (on_attach_rust: client: bufnr: [
              (vim.api.nvim_create_user_command "RustAndroid" (opts: [
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
              (CALL on_attach client bufnr)
            ])
            # BEGIN
            (let setupLsp' = { name, settings ? {} }: (lsp name).setup {
              inherit on_attach capabilities settings;
            };
            setupLsp = args: setupLsp' (if builtins.isString args then { name = args; } else args);
            in (on_attach_rust: [
              # (vim.lsp.set_log_level "debug")
              (map setupLsp [
                # see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
                "bashls"
                "clangd"
                # https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
                { name = "pylsp"; settings = {
                  pylsp.plugins.pylsp_mypy.enabled = true;
                }; }
                "svelte"
                "html"
                "cssls"
                "tsserver"
                "jsonls"
                "nil_ls"
                "taplo"
                "marksman"
              ])
              ((lsp "rust_analyzer").setup {
                on_attach = on_attach_rust;
                settings = rust_settings;
                inherit capabilities;
              })
            ]))) # END
          ])) # END
        ]); }
      { plugin = ps.which-key-nvim;
        config = compile "which_key_nvim" [
          (SET vim.o.timeout true)
          (SET vim.o.timeoutlen 500)
          (which-key.setup {})
        ]; }
    ];
  };
}
