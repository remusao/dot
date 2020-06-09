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

let g:ale_rust_cargo_check_all_targets = 1
let g:ale_rust_cargo_check_tests = 1
let g:ale_rust_cargo_use_clippy = 1
" let g:ale_rust_cargo_clippy_options = '-- -D warnings'

let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'typescript': ['tslint'],
\   'terraform': ['terraform'],
\   'c': ['clang-format'],
\   'swift': ['trim_whitespace'],
\   'rust': ['rustfmt'],
\}
" \   'javascript': ['eslint'],
" \   'python': ['black'],

let g:ale_fix_on_save = 1

let g:ale_completion_enabled = 0

let g:ale_linters = {
\   'javascript': ['eslint', 'tslint'],
\   'typescript': ['eslint', 'tsserver', 'tslint'],
\   'terraform': ['tflint'],
\   'rust': ['cargo', 'rustc', 'rls'],
\}

nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

let g:airline#extensions#ale#enabled = 1
let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_delay = 500
let g:ale_lint_on_save = 1
" let g:ale_max_signs = 10
let g:ale_set_signs = 1
let g:ale_set_highlights = 1
" }}}


" haskell-vim {{{
let g:haskell_enable_quantification = 1   " to enable highlighting of `forall`
let g:haskell_enable_recursivedo = 1      " to enable highlighting of `mdo` and `rec`
let g:haskell_enable_arrowsyntax = 1      " to enable highlighting of `proc`
let g:haskell_enable_pattern_synonyms = 1 " to enable highlighting of `pattern`
let g:haskell_enable_typeroles = 1        " to enable highlighting of type roles
let g:haskell_enable_static_pointers = 1  " to enable highlighting of `static`
let g:haskell_backpack = 1                " to enable highlighting of backpack keywords
let g:haskell_classic_highlighting = 1
" }}}


" vim LargeFile {{{
let g:LargeFile = 50
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

" vim-polyglot {{{
" let g:polyglot_disabled = ['latex', 'typescript']
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
let g:rustfmt_autosave = 0
let g:rustfmt_autosave_if_config_present = 0
let g:rust_use_custom_ctags_defs = 1
let g:rust_keep_autopairs_default = 0
" }}}
