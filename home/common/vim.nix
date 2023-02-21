{ config, pkgs, ... }:
{
  imports = [ ./options.nix ];
  programs.neovim = {
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
      python3Packages.python-lsp-server
    ];
    # extraPython3Packages = pyPkgs: with pyPkgs; [ python-lsp-server ];
    extraConfig = '' 
      autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
      syntax on
      au FileType markdown set colorcolumn=73 textwidth=72
      au FileType gitcommit set colorcolumn=73
      highlight NormalFloat guibg=NONE
    '';
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins =
    let lua = (s: ''
        lua << EOF
        ${s}
        EOF
      '');
    in with pkgs.vimPlugins; [
      vim-svelte
      # TODO remove on next nvim update (0.8.3/0.9)
      vim-nix
      { plugin = nvim-web-devicons;
        config = lua ''
        require'nvim-web-devicons'.setup {
        }
        ''; }
      { plugin = nvim-tree-lua;
        config = lua ''
          vim.g.loaded_netrw = 1
          vim.g.loaded_netrwPlugin = 1
          vim.opt.termguicolors = true
          require("nvim-tree").setup({
            -- :help nvim-tree-setup
          })
          local opts = { noremap=true, silent=true }
          vim.keymap.set('n', '<C-N>', require("nvim-tree.api").tree.toggle, opts)
          require("which-key").register({['<C-n>'] = {
            require("nvim-tree.api").tree.toggle, 'Toggle NvimTree'
          }}, {mode='n', noremap=true, silent=true})
        ''; }
      vim-sleuth
      luasnip
      { plugin = nvim-cmp;
        config = lua ''
          local cmp = require('cmp')
          local function border(hl_name)
            return {
              { "╭", hl_name },
              { "─", hl_name },
              { "╮", hl_name },
              { "│", hl_name },
              { "╯", hl_name },
              { "─", hl_name },
              { "╰", hl_name },
              { "│", hl_name },
            }
          end
          cmp.setup {
            snippet = {
              expand = function(args)
                require('luasnip').lsp_expand(args.body)
              end,
            },
            view = {
              
            },
            window = {
              completion = {
                border = border "CmpBorder",
                winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:None",
              },
              documentation = {
                border = border "CmpDocBorder",
              },
            },
            formatting = {
              format = function(_, vim_item)
                local icons = require("lspkind")
                vim_item.kind = string.format("%s %s", icons[vim_item.kind], vim_item.kind)
                return vim_item
              end,
            },
            mapping = {
              ['<C-p>'] = cmp.mapping.select_prev_item(),
              ['<C-n>'] = cmp.mapping.select_next_item(),
              ['<C-space>'] = cmp.mapping.complete(),
              ['<C-e>'] = cmp.mapping.close(),
              ['<cr>'] = cmp.mapping.confirm {
                behavior = cmp.ConfirmBehavior.Replace,
                select = false,
              },
              ['<tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                elseif require("luasnip").expand_or_jumpable() then
                  vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-expand-or-jump', true, true, true), "")
                else
                  fallback()
                end
              end, {
                "i",
                "s",
              }),
              ['<S-tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif require('luasnip').jumpable(-1) then
                  vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-jump-prev', true, true, true), "")
                else
                  fallback()
                end
              end, {
                "i",
                "s",
              }),
            },
            sources = cmp.config.sources({
              { name = 'nvim_lsp' },
              { name = 'luasnip' },
            }),
          }
        ''; }
      lspkind-nvim
      cmp_luasnip
      cmp-nvim-lsp
      { plugin = nvim-autopairs;
        config = lua ''
          require('nvim-autopairs').setup({
            disable_filetype = { "TelescopePrompt" , "vim" },
          })
          local cmp_autopairs = require('nvim-autopairs.completion.cmp')
          local cmp = require('cmp')
          cmp.event:on(
            'confirm_done',
            cmp_autopairs.on_confirm_done()
          )
        ''; }
      { plugin = comment-nvim;
        config = lua ''
          require('Comment').setup()
          local opts = { noremap=true, silent=true }
          vim.keymap.set('n', '<space>/', require("Comment.api").toggle.linewise.current, opts)
          vim.keymap.set('v', '<space>/', "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", opts)
          require("which-key").register({['<space>/'] = {
            require("Comment.api").toggle.linewise.current, 'Comment current line'
          }}, {mode='n', noremap=true, silent=true})
          require("which-key").register({['<space>/'] = {
            "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", 'Comment current line'
          }}, {mode='v', noremap=true, silent=true})

        ''; }
      { plugin = nvim-lspconfig;
        config = lua ''
          -- Mappings.
          -- See `:help vim.diagnostic.*` for documentation on any of the below functions
          local opts = { noremap=true, silent=true }
          vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
          vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)
          require("which-key").register({
            ['<space>e'] = { vim.diagnostic.open_float, 'Show diagnostics in a floating window.' },
            ['[d'] = { vim.diagnostic.goto_prev, 'Move to the previous diagnostic in the current buffer.' },
            [']d'] = { vim.diagnostic.goto_next, 'Get the next diagnostic closest to the cursor position.' },
            ['<space>q'] = { vim.diagnostic.setloclist, 'Add buffer diagnostics to the location list.' },
          }, {mode='n', noremap=true, silent=true})

          -- Use an on_attach function to only map the following keys
          -- after the language server attaches to the current buffer
          local on_attach = function(client, bufnr)
            -- Enable completion triggered by <c-x><c-o>
            vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

            -- Mappings.
            -- See `:help vim.lsp.*` for documentation on any of the below functions
            local bufopts = { noremap=true, silent=true, buffer=bufnr }
            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
            vim.keymap.set('n', '<C-h>', vim.lsp.buf.signature_help, bufopts)
            vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
            vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
            vim.keymap.set('n', '<space>wl', function()
              print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, bufopts)
            vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
            vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
            vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
            vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
            require("which-key").register({
              ['gD'] = { vim.lsp.buf.declaration, 'Jumps to the declaration of the symbol under the cursor.' },
              ['gd'] = { vim.lsp.buf.definition, 'Jumps to the definition of the symbol under the cursor.' },
              ['K'] = { vim.lsp.buf.hover, 'Displays hover information about the symbol under the cursor in a floating window.' },
              ['gi'] = { vim.lsp.buf.implementation, 'Lists all the implementations for the symbol under the cursor in the quickfix window.' },
              ['<C-h>'] = { vim.lsp.buf.signature_help, 'Displays signature information about the symbol under the cursor in a floating window.' },
              ['<space>wa'] = { vim.lsp.buf.add_workspace_folder, 'Add a folder to the workspace folders.' },
              ['<space>wr'] = { vim.lsp.buf.remove_workspace_folder, 'Remove a folder from the workspace folders.' },
              ['<space>wl'] = { function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
              end, 'List workspace folders.' },
              ['<space>D'] = { vim.lsp.buf.type_definition, 'Jumps to the definition of the type of the symbol under the cursor.' },
              ['<space>rn'] = { vim.lsp.buf.rename, 'Rename old_fname to new_fname' },
              ['<space>ca'] = { vim.lsp.buf.code_action, 'Selects a code action available at the current cursor position.' },
              ['gr'] = { vim.lsp.buf.references, 'Lists all the references to the symbol under the cursor in the quickfix window.' },
              ['<space>f'] = { function()
                vim.lsp.buf.format { async = true }
              end, 'Formats a buffer.' },
            }, {mode='n', noremap=true, silent=true, buffer=bufnr})
          end

          local lsp_flags = {
            -- This is the default in Nvim 0.7+
            debounce_text_changes = 150,
          }
          local capabilities = vim.tbl_extend(
            'keep',
            vim.lsp.protocol.make_client_capabilities(),
            require('cmp_nvim_lsp').default_capabilities()
          );
          -- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
          require'lspconfig'.bashls.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.clangd.setup{
            -- usually requires compile_flags.json
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.pylsp.setup{
            -- https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.svelte.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.html.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.cssls.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.tsserver.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.jsonls.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.nil_ls.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.taplo.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.marksman.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
          }
          require'lspconfig'.rust_analyzer.setup{
            on_attach = on_attach,
            flags = lsp_flags,
            capabilities = capabilities,
            -- Server-specific settings...
            settings = {
              ["rust-analyzer"] = {}
            }
          }
        ''; }
      { plugin = which-key-nvim;
        config = lua ''
          vim.o.timeout = true
          vim.o.timeoutlen = 500
          require("which-key").setup { }
        ''; }
    ];
  };
}
