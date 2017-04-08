"" --- CONFIGURE PLUGINS ---

" deoplete {{{
    " Enable omni completion.
    autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    autocmd FileType python setlocal omnifunc=jedi#completions
    autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

    let g:deoplete#omni#functions = {}
    let g:deoplete#omni#functions.javascript = [
      \ 'tern#Complete',
      \ 'jspc#omni'
    \]

    let g:deoplete#enable_at_startup = 1
    let g:deoplete#enable_ignore_case = 1
    let g:SuperTabDefaultCompletionType = "<c-x><c-o>"
    let g:UltiSnipsExpandTrigger="<C-j>"
    let g:SuperTabClosePreviewOnPopupClose = 1
    inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"

    let g:deoplete#sources = {}
    let g:deoplete#sources['javascript.jsx'] = ['ternjs', 'file', 'ultisnips']

    let g:tern#command = ['tern']
    let g:tern#arguments = ['--persistent']

    let g:tern_request_timeout = 1
    let g:tern_show_signature_in_pum = '1'  " This do disable full signature type on autocomplete
" }}}


" delimitMate {{{
    let delimitMate_expand_cr = 1
    augroup mydelimitMate
        au!
        au FileType markdown let b:delimitMate_nesting_quotes = ["`"]
        au FileType tex let b:delimitMate_quotes = ""
        au FileType tex let b:delimitMate_matchpairs = "(:),[:],{:},`:'"
        au FileType python let b:delimitMate_nesting_quotes = ['"', "'"]
    augroup END
" }}}


" ctrlp {{{
   let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
   if executable('rg')
       " Use rg over Grep
       set grepprg=rg\ --color\ never\ --no-heading
       " Use rg in CtrlP for listing files. Lightning fast and respects .gitignore
       let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
       " let g:ctrlp_user_command = 'rg --files  %s'
   endif
" }}}

" fzf {{{
    " [Buffers] Jump to the existing window if possible
    let g:fzf_buffers_jump = 1

    " [[B]Commits] Customize the options used by 'git log':
    let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'

    " Augmenting Ag command using fzf#vim#with_preview function
    "   * fzf#vim#with_preview([[options], preview window, [toggle keys...]])
    "     * For syntax-highlighting, Ruby and any of the following tools are required:
    "       - Highlight: http://www.andre-simon.de/doku/highlight/en/highlight.php
    "       - CodeRay: http://coderay.rubychan.de/
    "       - Rouge: https://github.com/jneen/rouge
    "
    "   :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
    "   :Ag! - Start fzf in fullscreen and display the preview window above
    command! -bang -nargs=* Ag
      \ call fzf#vim#ag(<q-args>,
      \                 <bang>0 ? fzf#vim#with_preview('up:60%')
      \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
      \                 <bang>0)

    " Likewise, Files command with preview window
    command! -bang -nargs=? -complete=dir Files
      \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
" }}}

" vim-gitgutter {{{
    " Required after having changed the colorscheme
    hi clear SignColumn
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
    let g:ale_linters = {
    \   'javascript': ['eslint'],
    \}

    nmap <silent> <C-k> <Plug>(ale_previous_wrap)
    nmap <silent> <C-j> <Plug>(ale_next_wrap)

    " Write this in your vimrc file
    let g:ale_lint_on_text_changed = 'never'
" }}}


" Neco-ghc {{{
    let g:necoghc_enable_detailed_browse = 1
    let g:haskellmode_completion_ghc = 0
" }}}


" vim LargeFile {{{
    let g:LargeFile = 50
" }}}


" jedi-vim {{{
    let g:jedi#completions_enabled = 0
    let g:jedi#auto_vim_configuration = 0
    let g:jedi#smart_auto_mappings = 0
" }}}

" vim-notes {{{
    let g:notes_directories = ['~/Private/Notes']
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
