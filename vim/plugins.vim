" Enable neobundle
filetype off
set runtimepath+=~/.vim/bundle/neobundle.vim/
call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

NeoBundle 'Shougo/vimproc.vim', {
\ 'build' : {
\     'linux' : 'make'
\    },
\ }
let g:neobundle#install_process_timeout = 1500

NeoBundle 'Shougo/neocomplcache.vim' " required by neco-ghc
NeoBundle 'Shougo/unite.vim'
NeoBundle 'JuliaLang/julia-vim'
NeoBundle 'MarcWeber/vim-addon-mw-utils'
NeoBundle 'Raimondi/delimitMate'
NeoBundle 'Shougo/neocomplete.vim'
NeoBundle 'Shougo/vimfiler.vim'
NeoBundle 'Shougo/vimshell.vim'
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'altercation/vim-colors-solarized'
NeoBundle 'bling/vim-airline'
NeoBundle 'chrisbra/csv.vim'
NeoBundle 'ctrlpvim/ctrlp.vim'
NeoBundle 'dag/vim2hs'
NeoBundle 'eagletmt/ghcmod-vim'
NeoBundle 'eagletmt/neco-ghc'
NeoBundle 'ervandew/supertab'
NeoBundle 'garbas/vim-snipmate'
NeoBundle 'godlygeek/tabular'
NeoBundle 'jistr/vim-nerdtree-tabs'
NeoBundle 'majutsushi/tagbar'
NeoBundle 'morhetz/gruvbox'
NeoBundle 'nanotech/jellybeans.vim'
NeoBundle 'ntpeters/vim-better-whitespace'
NeoBundle 'panagosg7/vim-annotations'
NeoBundle 'plasticboy/vim-markdown'
NeoBundle 'rking/ag.vim'
NeoBundle 'scrooloose/nerdcommenter'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'sheerun/vim-polyglot'
NeoBundle 'terryma/vim-multiple-cursors'
NeoBundle 'tomtom/tlib_vim'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-surround'
NeoBundle 'xolox/vim-easytags'
NeoBundle 'xolox/vim-misc'

call neobundle#end()

filetype plugin indent on " enable detection, plugins and indenting in one step
NeoBundleCheck


"" --- CONFIGURE PLUGINS --- ""

" ----- liquid Haskell "
"
let g:vim_annotations_offset = '/.liquid/'

" ----- ghc-mod -----
"
" autocmd BufWritePost *.hs,.hsc GhcModCheckAndLintAsync
map <silent> tw :GhcModTypeInsert<CR>
map <silent> ts :GhcModSplitFunCase<CR>
map <silent> tq :GhcModType<CR>
map <silent> te :GhcModTypeClear<CR>



" ----- SirVer/ultisnips settings -----
"
let g:UltiSnipsExpandTrigger="<c-0>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"


" ----- Raimondi/delimitMate settings -----
"
let delimitMate_expand_cr = 1
augroup mydelimitMate
 au!
 au FileType markdown let b:delimitMate_nesting_quotes = ["`"]
 au FileType tex let b:delimitMate_quotes = ""
 au FileType tex let b:delimitMate_matchpairs = "(:),[:],{:},`:'"
 au FileType python let b:delimitMate_nesting_quotes = ['"', "'"]
augroup END

" ----- kien/ctrlp settings -----
"
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
if executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor
  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
endif

" ----- airblade/vim-gitgutter settings -----
" Required after having changed the colorscheme
hi clear SignColumn
" In vim-airline, only display "hunks" if the diff is non-zero
let g:airline#extensions#hunks#non_zero_only = 1

" ----- xolox/vim-easytags settings -----
" Where to look for tags files
set tags=./tags;,~/.vimtags
" Sensible defaults
let g:easytags_events = ['BufReadPost', 'BufWritePost']
let g:easytags_async = 1
let g:easytags_dynamic_files = 2
let g:easytags_resolve_links = 1
let g:easytags_suppress_ctags_warning = 1

" ----- majutsushi/tagbar settings -----
" Open/close tagbar with \b
nmap <F8> :TagbarToggle<CR>
" Uncomment to open tagbar automatically whenever possible
"autocmd BufEnter * nested :call tagbar#autoopen(0)

" ----- jistr/vim-nerdtree-tabs -----
" Open/close NERDTree Tabs with \t
nmap <silent> <leader>t :NERDTreeTabsToggle<CR>
" To have NERDTree always open on startup
let g:nerdtree_tabs_open_on_console_startup = 0


" ----- airblade/vim-gitgutter settings -----
"
let g:gitgutter_max_signs = 500  " default value
let g:gitgutter_realtime = 0
let g:gitgutter_eager = 0

" ----- bling/vim-airline settings -----
"
set laststatus=2
let g:airline_detect_paste=1
let g:airline#extensions#tabline#enabled = 1

" ----- scrooloose/syntastic settings -----
let g:syntastic_python_checkers = ['pylint']
let g:syntastic_haskell_checkers = ["ghc-mod", "hint"]
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 0
let g:syntastic_error_symbol = '✘'

augroup mySyntastic
    au!
    au FileType tex let b:syntastic_mode = "passive"
augroup END

"" Julia
let g:julia_latex_to_unicode = 0
let g:latex_to_unicode_tab = 0

"" vim-markdown
let g:vim_markdown_folding_disabled=1

"" YouCompleteMe
let g:ycm_min_num_of_chars_for_completion = 1
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_collect_identifiers_from_tags_files = 1


