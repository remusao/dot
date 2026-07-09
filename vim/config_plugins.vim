"" --- CONFIGURE PLUGINS ---

" grep & fuzzy find {{{
" grepprg: nvim 0.12 auto-sets `rg --vimgrep -uu` + matching grepformat when rg is
" on PATH (column-accurate quickfix), so we don't override it here.
let g:fzf_layout = { 'window': { 'width': 1.0, 'height': 0.4, 'yoffset': 1.0, 'border': 'top' } }
let g:fzf_history_dir = '~/.local/share/fzf-history'
augroup user_fzf
  autocmd!
  autocmd FileType fzf tnoremap <buffer> <Esc> <Esc>
augroup END

function! s:project_files()
  let root = systemlist('git rev-parse --show-toplevel')[0]
  let spec = fzf#vim#with_preview({'options': ['--bind', 'ctrl-z:toggle+down']})
  if v:shell_error
    call fzf#vim#files('', spec, 0)
  else
    call fzf#vim#files(root, spec, 0)
  endif
endfunction

command! ProjectFiles call s:project_files()
nnoremap <silent> <C-p> :ProjectFiles<CR>
nnoremap <silent> <Leader>f :RG<CR>
nnoremap <silent> <Leader>b :Buffers<CR>
nnoremap <silent> <Leader>/ :BLines<CR>
nnoremap <silent> <Leader>h :History<CR>
nnoremap <silent> <Leader>g :GFiles?<CR>
" }}}

" Ale {{{
" Native vim.lsp owns LSP servers (pyright/vtsls/svelte/rust-analyzer/bashls/...).
" ALE handles non-LSP linters (ruff/mypy/eslint/tflint) and all fixers, feeding
" everything into vim.diagnostic.
let g:ale_disable_lsp = 1

let g:ale_python_mypy_ignore_invalid_syntax = 1

" Trailing-whitespace stripping is owned by vim-better-whitespace; ALE only
" handles trailing empty lines here (and per-language formatters below).
let g:ale_fixers = {
\   '*': ['remove_trailing_lines'],
\   'typescript': ['prettier'],
\   'javascript': ['eslint', 'prettier'],
\   'svelte': ['eslint', 'prettier'],
\   'terraform': ['terraform'],
\   'c': ['clang-format'],
\   'swift': ['trim_whitespace'],
\   'rust': ['rustfmt'],
\   'sh': ['shfmt'],
\   'lua': ['stylua'],
\   'ruby': ['rubocop', 'rufo'],
\   'python': ['ruff', 'ruff_format'],
\   'haskell': ['ormolu', 'fourmolu'],
\}

let g:ale_python_ruff_options = '--extend-select I'
" ruff lives in the neovim venv (off the interactive PATH), so point ALE at it
" explicitly -- otherwise the ruff linter + ruff_format fixer silently no-op.
let g:ale_python_ruff_executable = expand('~/.virtualenvs/neovim3/bin/ruff')
let g:ale_python_ruff_format_executable = expand('~/.virtualenvs/neovim3/bin/ruff')
" stylua defaults to tabs/120-col; match this config's 2-space indent.
let g:ale_lua_stylua_options = '--indent-type Spaces --indent-width 2'
let g:ale_fix_on_save = 1

let g:ale_linter_aliases = {
\   'svelte': ['javascript', 'svelte']
\}
let g:ale_linters = {
\   'javascript': ['eslint'],
\   'typescript': ['eslint'],
\   'svelte': ['eslint'],
\   'terraform': ['tflint'],
\   'python': ['ruff', 'mypy'],
\   'rust': [],
\}

" Diagnostic nav: vim.diagnostic.jump covers BOTH ALE and native LSP diagnostics.
nnoremap <silent> <C-k> <Cmd>lua vim.diagnostic.jump({count=-1, wrap=true})<CR>
nnoremap <silent> <C-j> <Cmd>lua vim.diagnostic.jump({count=1, wrap=true})<CR>

let g:ale_lint_delay = 2000
" ALE feeds its findings into vim.diagnostic (pinned -- the whole display design
" relies on it; vim.diagnostic then owns signs/underline).
let g:ale_use_neovim_diagnostics_api = 1
" These two ALE display paths are NOT gated by the flag above, so set them
" explicitly: no cmdline echo, and no ALE virtual_text (it would otherwise override
" the global virtual_text=false via per-namespace opts in vim.diagnostic.set()).
let g:ale_echo_cursor = 0
let g:ale_virtualtext_cursor = 'disabled'
" }}}


" vim-notes {{{
let g:notes_directories = ['~/Private/Notes', '~/dev/repositories/perso/remusao.github.io/notes']
let g:notes_suffix = '.note'
let g:notes_word_boundaries = 1
let g:notes_smart_quotes = 1
" }}}

lua << EOF
-- Parsers are installed by install.sh (require('nvim-treesitter').install); no runtime install here.
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    if vim.api.nvim_buf_line_count(args.buf) > 10000 then return end
    if pcall(vim.treesitter.start) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

require('nvim-autopairs').setup({})

-- Git signs in the gutter (gitsigns.nvim; async, replaces vim-gitgutter).
-- Defaults (┃/┃/▁/▔) render via the DejaVu Sans Mono fallback in urxvt.
require('gitsigns').setup()

-- Statusline (replaces vim-airline; reads vim.diagnostic + gitsigns directly).
require('lualine').setup({
  options = {
    theme = 'jellybeans',
    section_separators = { left = '', right = '' },
    component_separators = { left = '', right = '' },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = {
      'branch',
      { 'diff', source = function()
          local g = vim.b.gitsigns_status_dict
          if g then return { added = g.added, modified = g.changed, removed = g.removed } end
        end },
      'diagnostics',
    },
    lualine_c = { 'filename' },
    lualine_x = { 'encoding', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  tabline = { lualine_a = { 'buffers' }, lualine_z = { 'tabs' } },
})
EOF

" Native LSP (Neovim 0.11+: vim.lsp.config / vim.lsp.enable; uses nvim-lspconfig as catalog)
lua << EOF
-- Diagnostic display: gutter signs + a severity-tinted underline on the offending
-- token. urxvt can't render undercurl, so DiagnosticUnderline* (in colorscheme.vim)
-- use plain gui=underline + a subtle bg tint -- both urxvt-safe. No inline
-- virtual_text (it clutters half-typed lines); the message shows in a float instead.
vim.diagnostic.config({
  virtual_text = false,
  underline = true,
  signs = true,
  severity_sort = true,
  jump = { wrap = true },  -- jump.float is deprecated; the CursorHold float (below) shows the message
})

-- Hover-to-read: when the cursor rests on a diagnostic line (after 'updatetime' =
-- 250ms), pop the line's message(s) in a non-focusable float that auto-closes on
-- move. Normal mode only (CursorHold, not CursorHoldI) so it never fights
-- blink/copilot while typing. It's a floating window, not in-buffer text, so it
-- sidesteps the clutter/red-block issues that made us drop virtual_text.
-- Also on <C-w>d (built-in). To make it manual-only, delete this autocmd.
vim.api.nvim_create_autocmd('CursorHold', {
  group = vim.api.nvim_create_augroup('user_diagnostic_float', { clear = true }),
  callback = function()
    vim.diagnostic.open_float(nil, { focus = false, scope = 'line' })
  end,
})

-- pyright: run the server from ~/.virtualenvs/neovim3 (installed by install.sh).
vim.lsp.config('pyright', {
  cmd = { vim.fn.expand('~/.virtualenvs/neovim3/bin/pyright-langserver'), '--stdio' },
})

-- pyright has no venv auto-detection, and in a monorepo it roots at the git root
-- (where pyrightconfig.json lives, so extraPaths resolve) -- NOT the service dir.
-- So point it at the venv/.venv nearest the file being edited (uv/venv layouts).
-- Runs per buffer via LspAttach + didChangeConfiguration (the mechanism the
-- lspconfig catalog uses for :LspPyrightSetPythonPath) so switching between
-- services -- each with its own venv -- reconfigures correctly. $VIRTUAL_ENV,
-- if you activate one, is the fallback.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('user_pyright_venv', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= 'pyright' then return end
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(ev.buf))
    local venv = vim.fs.find({ 'venv', '.venv' }, { path = dir, upward = true, type = 'directory' })[1]
    local py = (venv and venv .. '/bin/python')
      or (vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV .. '/bin/python')
    if py and vim.uv.fs_stat(py) and (client.settings.python or {}).pythonPath ~= py then
      client.settings = vim.tbl_deep_extend('force', client.settings or {}, { python = { pythonPath = py } })
      client:notify('workspace/didChangeConfiguration', { settings = client.settings })
    end
  end,
})

-- rust-analyzer: clippy on check (modern key; checkOnSave.command is deprecated upstream).
vim.lsp.config('rust_analyzer', {
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
    },
  },
})

-- lua_ls: inject the Neovim runtime into the workspace library only when editing
-- this config, so vim.* globals resolve without false "undefined global" warnings.
vim.lsp.config('lua_ls', {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if path ~= vim.fn.stdpath('config')
        and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then
        return
      end
    end
    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua or {}, {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    })
  end,
  settings = { Lua = {} },
})

vim.lsp.enable({ 'pyright', 'rust_analyzer', 'vtsls', 'svelte', 'bashls', 'yamlls', 'lua_ls' })

-- Neovim ships grn/gra/grr/gri/grt/gO/K/<C-]> by default, but not gd.
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)

-- Copilot as ghost-text (copilot.lua). No built-in accept map -- blink drives <Tab> below.
require('copilot').setup({
  suggestion = { enabled = true, auto_trigger = true, keymap = { accept = false } },
  panel = { enabled = false },
  filetypes = {
    ['*'] = false,
    python = true, rust = true, javascript = true, typescript = true,
    svelte = true, sh = true, lua = true, haskell = true,
  },
})

-- Hide the Copilot ghost while blink's menu is open, so the two never overlap and
-- <Tab> unambiguously acts on whichever single UI is visible.
local cop = vim.api.nvim_create_augroup('user_copilot_blink', { clear = true })
vim.api.nvim_create_autocmd('User', { pattern = 'BlinkCmpMenuOpen', group = cop,
  callback = function() require('copilot.suggestion').dismiss(); vim.b.copilot_suggestion_hidden = true end })
vim.api.nvim_create_autocmd('User', { pattern = 'BlinkCmpMenuClose', group = cop,
  callback = function() vim.b.copilot_suggestion_hidden = false end })

-- Completion engine: blink.cmp (fuzzy as-you-type; LSP + path + snippets + buffer).
require('blink.cmp').setup({
  keymap = {
    preset = 'enter',                        -- <Up>/<Down> move, <Enter> accepts
    ['<Tab>'] = {
      'select_next',                         -- menu open: next item
      function()                             -- menu closed: accept Copilot ghost if shown
        local sug = require('copilot.suggestion')
        if sug.is_visible() then sug.accept(); return true end
      end,
      'fallback',                            -- else: a literal tab
    },
    ['<S-Tab>'] = { 'select_prev', 'fallback' },
    ['<C-l>'] = { 'snippet_forward', 'fallback' },
    ['<C-h>'] = { 'snippet_backward', 'fallback' },
  },
  completion = {
    list = { selection = { preselect = false } },
    ghost_text = { enabled = false },        -- Copilot owns inline ghost text
    -- Doc float the instant an item is highlighted. The default 500ms delay resets on
    -- every keypress and, with preselect=false (nothing selected until <Tab>), it almost
    -- never showed -- the "bare" feel vs YCM's preview panel. 0ms is async + debounced.
    documentation = { auto_show = true, auto_show_delay_ms = 0 },
    -- Re-open the menu when backspacing over letters inside a word (off by default).
    trigger = { show_on_backspace_in_keyword = true },
  },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  -- Signature help shows while typing arguments (after '(' or ','); show_documentation
  -- adds the function's docstring to that float (default shows the bare param list only).
  signature = { enabled = true, window = { show_documentation = true } },
  fuzzy = { implementation = 'prefer_rust_with_warning' },
})
EOF
