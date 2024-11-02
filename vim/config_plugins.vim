"" --- CONFIGURE PLUGINS ---

" delimitMate {{{
augroup mydelimitMate
    au!
    au FileType markdown let b:delimitMate_nesting_quotes = ["`"]
    au FileType python let b:delimitMate_nesting_quotes = ['"', "'"]
augroup END
" }}}

" ctrlp {{{
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
set grepprg=rg\ --color\ never\ --no-heading
let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
" rg is faster
" let g:ctrlp_user_command = 'fd --type f --color=never "" %s'
let g:ctrlp_match_func = {'match': 'cpsm#CtrlPMatch'}
let g:ctrlp_use_caching = 0
" }}}

" vim-airline {{{
set laststatus=2
let g:airline_detect_paste=1
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
" Only display "hunks" if the diff is non-zero
let g:airline#extensions#hunks#non_zero_only = 1
" }}}

" Ale {{{
let g:ale_python_black_executable = '/home/remi/.virtualenvs/neovim3/bin/black'

"" Cargo
let g:ale_rust_cargo_use_check = 1
let g:ale_rust_cargo_check_all_targets = 1
let g:ale_rust_cargo_check_tests = 1
let g:ale_rust_cargo_check_examples = 1
let g:ale_rust_cargo_default_feature_behavior = 'all'
let g:ale_rust_cargo_avoid_whole_workspace = 0
let g:ale_rust_analyzer_config = {
    \ 'cargo': { 'allFeatures': v:true },
    \ 'procMacro': { 'enable': v:true },
    \ 'checkOnSave': { 'command': 'clippy', 'enable': v:true, 'extraArgs': '--all-targets' }
    \ }

"" Clippy
let g:ale_rust_cargo_use_clippy = 1
" let g:ale_rust_cargo_clippy_options = '-D warnings -W clippy::cargo -W clippy::all -W clippy::pedantic'

"" Mypy
let g:ale_python_mypy_ignore_invalid_syntax = 1

let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'typescript': ['tslint', 'prettier'],
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
let g:ale_linters = {
\   'javascript': ['eslint', 'tslint', 'tsserver'],
\   'typescript': ['eslint', 'tsserver', 'tslint'],
\   'svelte': ['svelteserver', 'eslint'],
\   'terraform': ['tflint'],
\   'python': ['ruff', 'pyright', 'mypy', 'ruff_format'],
\   'rust': ['analyzer'],
\}

nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

let g:airline#extensions#ale#enabled = 1
let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_delay = 2000
let g:ale_lint_on_save = 1
" let g:ale_max_signs = 10
let g:ale_set_signs = 1
let g:ale_set_highlights = 1
let g:ale_virtualtext_cursor = 'disabled'
" }}}


" haskell-vim {{{
let g:haskell_enable_quantification = 1   " to enable highlighting of `forall`
let g:haskell_enable_recursivedo = 1      " to enable highlighting of `mdo` and `rec`
let g:haskell_enable_arrowsyntax = 1      " to enable highlighting of `proc`
let g:haskell_enable_pattern_synonyms = 1 " to enable highlighting of `pattern`
let g:haskell_enable_typeroles = 1        " to enable highlighting of type roles
let g:haskell_enable_static_pointers = 1  " to enable highlighting of `static`
let g:haskell_backpack = 1                " to enable highlighting of backpack keywords
" let g:haskell_classic_highlighting = 1
let g:haskell_indent_disable = 1
" }}}


" vim-notes {{{
let g:notes_directories = ['~/Private/Notes', '~/dev/repositories/perso/remusao.github.io/notes']
let g:notes_suffix = '.note'
let g:notes_word_boundaries = 1
let g:notes_smart_quotes = 1
" }}}


" writing {{{
let g:vim_markdown_override_foldtext = 0
let g:vim_markdown_math = 1
let g:vim_markdown_toml_frontmatter = 1
let g:vim_markdown_json_frontmatter = 1

let g:vim_markdown_new_list_item_indent = 2
" }}}

" vim-javascript {{{
let g:javascript_plugin_jsdoc = 1
" }}}

" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
" }}}

" UtilSnip {{{
let g:UltiSnipsExpandTrigger = '<C-j>'
let g:UltiSnipsJumpForwardTrigger = '<C-j>'
let g:UltiSnipsJumpBackwardTrigger = '<C-k>'
let g:ultisnips_python_style = 'google'
" }}}

" jiangmiao/auto-pairs {{{
let g:AutoPairsMultilineClose = 0
" }}}

" Terraform {{{
" let g:terraform_fmt_on_save = 1
let g:terraform_align = 1
" }}}

" YouCompleteMe {{{
let g:ycm_show_diagnostics_ui = 0
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_add_preview_to_completeopt = 1
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_semantic_triggers = {
     \ 'elm' : ['.'],
     \ 'haskell' : ['re![^ ]+'],
     \}

let s:lsp = '/home/remi/.dot/vim/lsp'
let g:ycm_language_server = [
  \   {
  \     'name': 'bash',
  \     'cmdline': [ 'node', '/home/remi/.nvm/versions/node/v22.11.0/bin/bash-language-server', 'start' ],
  \     'filetypes': [ 'sh', 'bash' ],
  \   },
  \   {
  \     'name': 'yaml',
  \     'cmdline': [ 'node', '/home/remi/.nvm/versions/node/v22.11.0/bin/yaml-language-server', '--stdio' ],
  \     'filetypes': [ 'yaml' ],
  \   },
  \   { 'name': 'docker',
  \     'filetypes': [ 'dockerfile' ],
  \     'cmdline': [ '/home/remi/.nvm/versions/node/v22.11.0/bin/docker-langserver', '--stdio' ]
  \   },
  \   {
  \     'name': 'haskell-language-server',
  \     'cmdline': [ 'haskell-language-server-wrapper', '--lsp' ],
  \     'filetypes': [ 'haskell', 'lhaskell' ],
  \     'project_root_files': [ 'stack.yaml', 'cabal.project', 'package.yaml', 'hie.yaml' ],
  \   },
  \   { 'name': 'lua',
  \     'filetypes': [ 'lua' ],
  \     'cmdline': [ '/home/remi/.sandboxes/firefox/Downloads/lua-language-server-3.7.4-linux-x64/bin/lua-language-server' ],
  \     'capabilities': { 'textDocument': { 'completion': { 'completionItem': { 'snippetSupport': v:true } } } },
  \     'triggerCharacters': []
  \   },
  \   {
  \     'name': 'svelte',
  \     'cmdline': [ 'node', '/home/remi/.nvm/versions/node/v22.11.0/bin/svelteserver', '--stdio' ],
  \     'filetypes': [ 'svelte' ],
  \   },
  \ ]
" }}}


" editorconfig {{{
let g:EditorConfig_exclude_patterns = ['fugitive://.*']
let g:EditorConfig_exec_path = '/home/remi/.local/bin/editorconfig'
" }}}

" rust {{{
let g:rust_conceal = 0
let g:rust_conceal_mod_path = 0
let g:rust_conceal_pub = 0
let g:rust_recommended_style = 1
let g:rust_fold = 0
let g:rustfmt_autosave = 1
let g:rustfmt_autosave_if_config_present = 0
let g:rust_use_custom_ctags_defs = 1
let g:rust_keep_autopairs_default = 0
" }}}

" Rainbow {{{
" let g:rainbow#max_level = 16
" let g:rainbow#pairs = [['{', '}'], ['(', ')'], ['[', ']']]
" augroup rainbow_lisp
"   autocmd!
"   autocmd FileType typescript,javascript,lisp,clojure,scheme RainbowParentheses
" augroup END
" }}}

" vim-python {{{
let g:python_highlight_all = 1
let g:python_version_2 = 0
let g:python_highlight_indent_errors = 0
let g:python_highlight_space_errors = 0
let g:python_highlight_func_calls = 0
" }}}

let g:vim_svelte_plugin_use_typescript = 1

lua << EOF
-- vim.o.timeout = true
-- vim.o.timeoutlen = 100
-- require("which-key").setup({})

local api = vim.api
local function ts_disable(_, bufnr)
    return api.nvim_buf_line_count(bufnr) > 10000
end

require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all"
  ensure_installed = { "svelte", "typescript", "html", "css", "javascript", "python", "rust", "yaml", "json", "bash", "make", "lua", "toml" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = true,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
    enable = true,
    disable = ts_disable,
    additional_vim_regex_highlighting = false,
  },

  incremental_selection = {
    enable = true,
  },

  indent = {
    enable = true,
    -- disable = {"svelte", "html", "javascript", "typescript", "rust", "toml"}
  },

}
EOF


" Copilot
" imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
" let g:copilot_no_tab_map = v:true

let g:copilot_filetypes = {
      \ '*': v:false,
      \ 'haskell': v:true,
      \ 'javascript': v:true,
      \ 'python': v:true,
      \ 'rust': v:true,
      \ 'sh': v:true,
      \ 'svelte': v:true,
      \ 'typescript': v:true,
      \ }
