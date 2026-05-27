"" --- CONFIGURE PLUGINS ---

" grep & fuzzy find {{{
set grepprg=rg\ --color\ never\ --no-heading
let g:fzf_layout = { 'window': { 'width': 1.0, 'height': 0.4, 'yoffset': 1.0, 'border': 'top' } }
let g:fzf_history_dir = '~/.local/share/fzf-history'
augroup user_fzf
  autocmd!
  autocmd FileType fzf silent! tunmap <buffer> <C-z>
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

" vim-airline {{{
let g:airline_detect_paste=1
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
" Only display "hunks" if the diff is non-zero
let g:airline#extensions#hunks#non_zero_only = 1
" }}}

" Ale {{{
" Native vim.lsp owns LSP-style linters (pyright/tsserver/svelteserver/rust-analyzer).
" ALE handles non-LSP linters (ruff/mypy/eslint/tflint) and all fixers.
let g:ale_disable_lsp = 1

"" Cargo
let g:ale_rust_cargo_use_check = 1
let g:ale_rust_cargo_check_all_targets = 1
let g:ale_rust_cargo_check_tests = 1
let g:ale_rust_cargo_check_examples = 1
let g:ale_rust_cargo_default_feature_behavior = 'all'
let g:ale_rust_cargo_avoid_whole_workspace = 0

"" Clippy
let g:ale_rust_cargo_use_clippy = 1
" let g:ale_rust_cargo_clippy_options = '-D warnings -W clippy::cargo -W clippy::all -W clippy::pedantic'

"" Mypy
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
\   'ruby': ['rubocop', 'rufo'],
\   'python': ['ruff', 'ruff_format'],
\   'haskell': ['ormolu', 'fourmolu'],
\}

let g:ale_python_ruff_options = '--extend-select I'
" let g:ale_python_ruff_change_directory = 0

let g:ale_fix_on_save = 1

let g:ale_completion_enabled = 0

" NOTE: for rust I removed 'rustc' as it does not know about the dependencies
" somehow so whole files are highlighted with warnings.
let g:ale_linter_aliases = {
\   'svelte': ['javascript', 'svelte']
\}
" LSP linters (pyright, tsserver, svelteserver, analyzer) removed: handled by native vim.lsp.
" ruff_format is a formatter (see g:ale_fixers), not a linter -- removed from python.
let g:ale_linters = {
\   'javascript': ['eslint'],
\   'typescript': ['eslint'],
\   'svelte': ['eslint'],
\   'terraform': ['tflint'],
\   'python': ['ruff', 'mypy'],
\   'rust': [],
\}

" Diagnostic nav: vim.diagnostic.jump covers BOTH ALE and native LSP diagnostics,
" unlike <Plug>(ale_*_wrap) which only iterates ALE's internal loclist.
nnoremap <silent> <C-k> <Cmd>lua vim.diagnostic.jump({count=-1, wrap=true})<CR>
nnoremap <silent> <C-j> <Cmd>lua vim.diagnostic.jump({count=1, wrap=true})<CR>

let g:airline#extensions#ale#enabled = 1
let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_delay = 2000
let g:ale_lint_on_save = 1
" let g:ale_max_signs = 10
let g:ale_set_signs = 1
let g:ale_set_highlights = 1
let g:ale_virtualtext_cursor = 'disabled'
" }}}


" vim-notes {{{
let g:notes_directories = ['~/Private/Notes', '~/dev/repositories/perso/remusao.github.io/notes']
let g:notes_suffix = '.note'
let g:notes_word_boundaries = 1
let g:notes_smart_quotes = 1
" }}}


" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
" }}}

" rust {{{
let g:rust_conceal = 0
let g:rust_conceal_mod_path = 0
let g:rust_conceal_pub = 0
let g:rust_recommended_style = 1
let g:rust_fold = 0
let g:rustfmt_autosave = 0  " ALE owns rustfmt via g:ale_fixers (avoid double-fire on save)
let g:rustfmt_autosave_if_config_present = 0
let g:rust_use_custom_ctags_defs = 1
" }}}

lua << EOF
-- Parsers are installed by install.sh via TSInstallSync!; no runtime install needed.
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    if vim.api.nvim_buf_line_count(args.buf) > 10000 then return end
    if pcall(vim.treesitter.start) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

require('nvim-autopairs').setup({})
EOF


" Copilot
" imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
" let g:copilot_no_tab_map = v:true

" Use the copilot-language-server bundled inside the plugin instead of
" re-downloading via npx on every launch (eliminates 'npm warn exec' in lsp.log).
let g:copilot_version = v:false

let g:copilot_filetypes = {
      \ '*': v:false,
      \ 'haskell': v:true,
      \ 'javascript': v:true,
      \ 'python': v:true,
      \ 'rust': v:true,
      \ 'sh': v:true,
      \ 'svelte': v:true,
      \ 'typescript': v:true,
      \ 'lua': v:true,
      \ }

" Native LSP (Neovim 0.11+: vim.lsp.config / vim.lsp.enable; uses nvim-lspconfig as catalog)
lua << EOF
-- Override pyright cmd to use the binary inside ~/.virtualenvs/neovim3 (installed by install.sh).
-- nvim-lspconfig's lsp/pyright.lua provides filetypes, root_markers, settings; we merge on top.
vim.lsp.config('pyright', {
  cmd = { vim.fn.expand('~/.virtualenvs/neovim3/bin/pyright-langserver'), '--stdio' },
})

-- rust-analyzer: enable clippy on check (modern key; checkOnSave.command is deprecated upstream).
vim.lsp.config('rust_analyzer', {
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
    },
  },
})

vim.lsp.enable({ 'pyright', 'rust_analyzer', 'ts_ls', 'svelte', 'bashls', 'yamlls' })

-- Enable native LSP completion per-buffer when a capable client attaches.
-- Built-in 0.12 defaults handle K/grn/gra/grr/gri/grt/gO/<C-S>/<C-]>; nothing else needed here.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('user_lsp_attach', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, args.data.client_id, args.buf, { autotrigger = true })
    end
  end,
})
EOF
