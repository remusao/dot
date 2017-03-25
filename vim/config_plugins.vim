"" --- CONFIGURE PLUGINS ---

" deoplete {{{
    " Enable omni completion.
    autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
    autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    autocmd FileType python setlocal omnifunc=jedi#completions
    autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
    autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

    let g:deoplete#enable_at_startup = 1
    let g:deoplete#enable_ignore_case = 1
    let g:SuperTabDefaultCompletionType = "<c-x><c-o>"
    let g:UltiSnipsExpandTrigger="<C-j>"
    let g:SuperTabClosePreviewOnPopupClose = 1
    inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"

    let g:deoplete#omni#functions = {}
    let g:deoplete#omni#functions.javascript = [
      \ 'tern#Complete',
      \ 'jspc#omni'
    \]

    set completeopt=longest,menuone,preview
    let g:deoplete#sources = {}
    let g:deoplete#sources['javascript.jsx'] = ['file', 'ultisnips', 'ternjs']
    let g:tern#command = ['tern']
    let g:tern#arguments = ['--persistent']

    let g:tern_request_timeout = 1
    let g:tern_show_signature_in_pum = '0'  " This do disable full signature type on autocomplete

    " Disable infobox
    set completeopt-=preview
" }}}


" ghc-mod {{{
    map <silent> tw :GhcModTypeInsert<CR>
    map <silent> ts :GhcModSplitFunCase<CR>
    map <silent> tq :GhcModType<CR>
    map <silent> te :GhcModTypeClear<CR>

    hi ghcmodType ctermbg=yellow
    let g:ghcmod_type_highlight = 'ghcmodType'
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
        " Use rh over Grep
        set grepprg=rg\ --color\ never\ --no-heading
        " Use rg in CtrlP for listing files. Lightning fast and respects .gitignore
        let g:ctrlp_user_command = 'rg --files  %s'
    endif
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
    nmap <silent> <C-k> <Plug>(ale_previous_wrap)
    nmap <silent> <C-j> <Plug>(ale_next_wrap)
" }}}
" Neomake {{{
""    autocmd! BufEnter,BufWritePost * Neomake
""    " neomake
""    nmap <Leader><Space>o :lopen<CR>   " open location window
""    nmap <Leader><Space>c :lclose<CR>  " close location window
""    nmap <Leader><Space>, :ll<CR>      " go to current error/warning
""    nmap <Leader><Space>n :lnext<CR>   " next error/warning
""    nmap <Leader><Space>p :lprev<CR>   " previous error/warning
" }}}


" ghc-mod {{{
" autocmd BufWritePost *.hs GhcModCheckAndLintAsync
" }}}


" Neco-ghc {{{
    let g:necoghc_enable_detailed_browse = 1
    let g:haskellmode_completion_ghc = 0
" }}}


" vim LargeFile {{{
    let g:LargeFile = 50
" }}}


" jedi-vim {{{
    autocmd FileType python setlocal omnifunc=jedi#completions
    let g:jedi#completions_enabled = 0
    let g:jedi#auto_vim_configuration = 0
    let g:jedi#smart_auto_mappings = 0
" }}}
"

" vim-notes {{{
    let g:notes_directories = ['~/Private/Notes']
    let g:notes_suffix = '.note'
    let g:notes_word_boundaries = 1
    let g:notes_smart_quotes = 1
" }}}


" vim-multiple-cursors {{{
" }}}
