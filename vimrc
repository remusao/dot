" ####################
" # General Settings #
" ####################

" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

set antialias

" allow backspacing over everything in insert mode
set backspace=indent,eol,start
set history=1000 " keep 1000 lines of command line history
set number " show line numbers
set ruler " show the cursor position all the time
set showcmd " display incomplete commands
set incsearch " do incremental searching
set splitright " Vertical splits use right half of screen
set timeoutlen=100 " Lower ^[ timeout
set fillchars=fold:\ , " get rid of obnoxious '-' characters in folds
set tildeop " use ~ to toggle case as an operator, not a motion
if exists('breakindent')
    set breakindent " Indent wrapped lines up to the same level
endif
" Tab settings
set expandtab " Expand tabs into spaces
set tabstop=4 " default to 4 spaces for a hard tab
set softtabstop=4 " default to 4 spaces for the soft tab
set shiftwidth=4 " for when <TAB> is pressed at the beginning of a line
set autoindent " always set autoindenting on
set copyindent " copy the previous indentation on autoindenting
set hidden
set hlsearch is " highlight search terms
set ignorecase " ignore case when searching
if v:version >= 730
    set undofile " keep a persistent backup file
    set undodir=~/.vim/.undo,~/tmp,/tmp
endif
set nobackup
set noswapfile
set directory=~/.vim/.tmp,~/tmp,/tmp " store swap files in one of these directories
set nowrap " don't wrap lines
set shiftround " use multiple of shiftwidth when indenting with '<' and '>'
set showmatch " set show matching parenthesis
set smartcase " ignore case if search pattern is all lowercase, " case-sensitive otherwise
set smartindent
set smarttab " insert tabs on the start of a line according to shiftwidth, not tabstop
set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip " Ignore this extension in file searching
" Complete options (disable preview scratch window)
set completeopt=menu,menuone,longest
" Limit popup menu height
set pumheight=15
set lazyredraw " don't update the display while executing macros
set switchbuf=useopen " reveal already opened files from the
" quickfix window instead of opening new
" buffers
set wildmenu " make tab completion for files/buffers act like bash
set wildmode=list:longest,full
" first full match
set cursorline " underline the current line, for quick orientation
set title
set pastetoggle=<F12>

" Workaround vim-commentary for Haskell
autocmd FileType haskell setlocal commentstring=--\ %s
" Workaround broken colour highlighting in Haskell
autocmd FileType haskell,rust setlocal nospell


" Make these commonly mistyped commands still work
command! WQ wq
command! Wq wq
command! Wqa wqa
command! W w
command! Q q

" open help in a new tab
cabbrev help tab help

" Make navigating long, wrapped lines behave like normal lines
noremap <silent> k gk
noremap <silent> j gj
noremap <silent> 0 g0
noremap <silent> $ g$
noremap <silent> ^ g^
noremap <silent> _ g_

" use 'Y' to yank to the end of a line, instead of the whole line
noremap <silent> Y y$

" Enable neobundle
filetype off
set runtimepath+=~/.vim/bundle/neobundle.vim/
call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

NeoBundle 'Shougo/vimproc.vim', {
\ 'build' : {
\     'windows' : 'tools\\update-dll-mingw',
\     'cygwin' : 'make -f make_cygwin.mak',
\     'mac' : 'make -f make_mac.mak',
\     'linux' : 'make',
\     'unix' : 'gmake',
\    },
\ }

NeoBundle 'JuliaLang/julia-vim'
NeoBundle 'Raimondi/delimitMate'
NeoBundle 'Shougo/neocomplcache.vim' " required by neco-ghc
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimfiler.vim'
NeoBundle 'Shougo/vimshell.vim'
NeoBundle 'SirVer/ultisnips'
NeoBundle 'Valloric/YouCompleteMe', { 'build_commands' : 'cmake' }
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'altercation/vim-colors-solarized'
NeoBundle 'bling/vim-airline'
NeoBundle 'chrisbra/csv.vim'
NeoBundle 'dag/vim2hs'
NeoBundle 'eagletmt/neco-ghc'
NeoBundle 'godlygeek/tabular'
NeoBundle 'honza/vim-snippets'
NeoBundle 'jistr/vim-nerdtree-tabs'
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'majutsushi/tagbar'
NeoBundle 'morhetz/gruvbox'
NeoBundle 'nanotech/jellybeans.vim'
NeoBundle 'ntpeters/vim-better-whitespace'
NeoBundle 'plasticboy/vim-markdown'
NeoBundle 'rking/ag.vim'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'sheerun/vim-polyglot'
NeoBundle 'terryma/vim-multiple-cursors'
NeoBundle 'tomasr/molokai'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-surround'
NeoBundle 'xolox/vim-easytags'
NeoBundle 'xolox/vim-misc'

call neobundle#end()

filetype plugin indent on " enable detection, plugins and indenting in one step
NeoBundleCheck

" Set encoding
set encoding=utf-8
set fileencoding=utf-8

""" Syntax Coloration
syntax on
set background=dark
set t_Co=256
" using Inconsolata font in gvim
set anti enc=utf-8
if has("gui_running")
    let g:solarized_termcolors=256
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized " Load a colorscheme"
    set guifont=Inconsolata\ Medium\ 16
    set guioptions-=m  "remove menu bar
    set guioptions-=T  "remove toolbar
    set guioptions-=r  "remove right-hand scroll bar
    set guioptions-=L  "remove left-hand scroll bar
else
    colorscheme jellybeans
    hi Normal ctermbg=NONE
endif


"" --- CONFIGURE PLUGINS --- ""

" ----- ghc-mod -----
"
autocmd BufWritePost *.hs,.hsc GhcModCheckAndLintAsync



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
let g:syntastic_haskell_checkers = ["hint"]
let g:syntastic_always_populate_loc_list = 1
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


""python highlighting extras
let python_highlight_all = 1

""" Additionnal Mappings
nnoremap ; :
nmap <silent> ./ :nohlsearch<CR>

""" Define map <Leader>
let mapleader = ","


" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

if has("autocmd")
" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid or when inside an event handler
" (happens when dropping a file on gvim).
    autocmd BufReadPost *
                \ if line("'\"") > 0 && line("'\"") <= line("$") |
                \ execute "normal! g`\"" |
                \ endif

" When editing a new file, load skeleton if any.
" If we find <+FILENAME+> in skeleton, replace it by the filename.
" If we find <+HEADERNAME+> in skeleton, replace it by the filename
" uppercase with . replaced by _ (foo.h become FOO_H).
    autocmd BufNewFile *
                \ let skel = $HOME . "/.vim/skeletons/skel." . expand("%:e") |
                \ if filereadable(skel) |
                \ execute "silent! 0read " . skel |
                \ let fn = expand("%") |
                \ let hn = substitute(expand("%"), "\\w", "\\u\\0", "g") |
                \ let hn = substitute(hn, "\\.", "_", "g") |
                \ let hn = substitute(hn, "/", "_", "g") |
                \ let cn = expand("%:t:r") |
                \ %s/<+FILENAME+>/\=fn/Ige |
                \ %s/<+HEADERNAME+>/\=hn/Ige |
                \ %s/<+CLASSNAME+>/\=cn/Ige |
                \ unlet fn hn cn |
                \ endif |
                \ unlet skel |
                \ goto 1
endif " has autocmd


"Limit the width of text for mutt to 80 columns
au BufRead /tmp/mutt-* set tw=80

" Git commit preference
autocmd Filetype gitcommit setlocal spell textwidth=72
