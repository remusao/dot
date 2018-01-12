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
   if executable('rg')
       set grepprg=rg\ --color\ never\ --no-heading
       let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
   endif
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
    let g:ale_fixers = {}
    let g:ale_fix_on_save = 0

    let g:ale_completion_enabled = 0

    let g:ale_linters = {
    \   'javascript': ['eslint'],
    \   'typescript': ['tslint', 'tsserver'],
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


" Neco-ghc {{{
    let g:necoghc_enable_detailed_browse = 1
    let g:haskellmode_completion_ghc = 0
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

" vim-polyglot {{{
let g:javascript_plugin_jsdoc = 1
" }}}

" YouCompleteMe {{{
let g:ycm_python_binary_path = 'python'
let g:ycm_semantic_triggers = {
    \'haskell' : ['.'],
    \'go' : ['.'],
    \ }
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_auto_start_csharp_server = 0

let g:ycm_filetype_blacklist = {
      \ 'tagbar' : 1,
      \ 'qf' : 1,
      \ 'unite' : 1,
      \ 'text' : 1,
      \ 'vimwiki' : 1,
      \ 'infolog' : 1,
      \ 'mail' : 1
      \}

autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc
" }}}
