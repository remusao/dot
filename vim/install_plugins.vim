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

" General addons
NeoBundle 'MarcWeber/vim-addon-mw-utils'
NeoBundle 'xolox/vim-misc'
NeoBundle 'tomtom/tlib_vim'
NeoBundle 'Shougo/unite.vim'

NeoBundle 'Raimondi/delimitMate' " Automatic closing of quotes, parenthesis, brackets, etc.
NeoBundle 'Shougo/neocomplete.vim' " Auto-completion engine
NeoBundle 'Shougo/vimshell.vim' " Shell integration in Vim
NeoBundle 'airblade/vim-gitgutter' " Show git diff in Vim
NeoBundle 'bling/vim-airline' " Vim powerline
NeoBundle 'ctrlpvim/ctrlp.vim' " File searching from Vim
NeoBundle 'godlygeek/tabular' " Align stuff
NeoBundle 'jistr/vim-nerdtree-tabs' " :NERDTreeTabsToggle to display in all tabs
NeoBundle 'jlanzarotta/bufexplorer'
NeoBundle 'ntpeters/vim-better-whitespace' " Highlight and strip trailing whitespaces
NeoBundle 'rking/ag.vim' " Silver searcher from Vim
NeoBundle 'scrooloose/nerdtree' " Nerdtree
NeoBundle 'scrooloose/syntastic' " Syntax checking
NeoBundle 'sheerun/vim-polyglot'
NeoBundle 'terryma/vim-multiple-cursors' " Multi cursors
NeoBundle 'tpope/vim-abolish'
NeoBundle 'tpope/vim-eunuch'
NeoBundle 'tpope/vim-repeat'
NeoBundle 'vim-airline/vim-airline'
NeoBundle 'vim-airline/vim-airline-themes'
NeoBundle 'xolox/vim-notes'
NeoBundle 'xolox/vim-shell'
NeoBundle 'vim-scripts/LargeFile'
NeoBundle 'haya14busa/incsearch.vim'
NeoBundle 'Konfekt/FastFold'

" Colors
NeoBundle 'altercation/vim-colors-solarized'
NeoBundle 'nanotech/jellybeans.vim'


" Markdown
NeoBundleLazy 'plasticboy/vim-markdown', {
      \ 'autoload' : {
      \     'filetypes' : ['markdown'],
      \    },
      \ }


" CSV
NeoBundleLazy 'chrisbra/csv.vim', {
      \ 'autoload' : {
      \     'filetypes' : ['csv'],
      \    },
      \ }


" c/cpp
NeoBundleLazy 'Rip-Rip/clang_complete', {
      \ 'autoload' : {
      \     'filetypes' : ['c', 'cpp'],
      \    },
      \ }


" Python
NeoBundleLazy 'hdima/python-syntax', {
      \ 'autoload' : {
      \     'filetypes' : ['python', 'python3'],
      \    },
      \ }
NeoBundleLazy 'davidhalter/jedi-vim', {
      \ 'autoload' : {
      \     'filetypes' : ['python', 'python3'],
      \    },
      \ }


" Julia
" NeoBundleLazy 'JuliaLang/julia-vim', {
"       \ 'autoload' : {
"       \     'filetypes' : ['julia'],
"       \    },
"       \ }


" Haskell
NeoBundleLazy 'dag/vim2hs', {
      \ 'autoload' : {
      \     'filetypes' : ['haskell'],
      \    },
      \ }
NeoBundleLazy 'eagletmt/ghcmod-vim', {
      \ 'autoload' : {
      \     'filetypes' : ['haskell'],
      \    },
      \ }
NeoBundleLazy 'eagletmt/neco-ghc', { 'autoload' : {
      \ 'filetypes' : 'haskell'
      \ }}

call neobundle#end()

filetype plugin indent on " enable detection, plugins and indenting in one step
NeoBundleCheck
