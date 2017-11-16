" Enable vim-plug
filetype off

call plug#begin('~/.local/share/nvim/plugged')

" linting
Plug 'w0rp/ale'

" Autocomplete
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --js-completer --rust-completer --clang-completer --go-completer' }

" Plug 'ervandew/supertab'
Plug 'Raimondi/delimitMate'                                 " Automatic closing of quotes, parenthesis, brackets, etc.
Plug 'airblade/vim-gitgutter'                               " Show git diff in Vim
Plug 'tpope/vim-fugitive'                                   " Git integration in Vim
" Plug 'tpope/vim-surround'                                   " Surround stuff
" Plug 'tpope/vim-repeat'                                     " Repeat stuff
" Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }     " Nerdtree

" Fuzzy search
Plug 'ctrlpvim/ctrlp.vim'               " Fuzzy file searching from Vim
" Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
" Plug 'junegunn/fzf.vim'

Plug 'ntpeters/vim-better-whitespace'                       " Highlight and strip trailing whitespaces
Plug 'terryma/vim-multiple-cursors'                         " Multi cursors
Plug 'xolox/vim-notes', { 'for': 'notes', 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': 'notes', 'on': 'Note' }     " Dependency of vim-notes
Plug 'mhinz/vim-hugefile'                                   " Read huge files efficiently

" Colors
Plug 'nanotech/jellybeans.vim'              " The only theme I ever liked...
Plug 'vim-airline/vim-airline'              " Vim powerline
Plug 'vim-airline/vim-airline-themes'       " Themes for powerline

" Javascript
" vim-polyglot

" Language support
Plug 'sheerun/vim-polyglot'                 " Huge language pack
Plug 'sbdchd/neoformat'                     " Formatting code

" Typescript
" vim-polyglot
Plug 'mhartington/nvim-typescript', {'for': 'typescript'}

" CSS
" vim-polyglot
Plug 'chrisbra/Colorizer', {'for': 'css'}

" Rust
" vim-polyglot

" Markdown
" vim-polyglot
Plug 'junegunn/goyo.vim', {'for': ['latex', 'tex', 'markdown']}
Plug 'plasticboy/vim-markdown', {'for': ['latex', 'tex', 'markdown']}

" Latex
" vim-polyglot
Plug 'lervag/vimtex', { 'for': ['latex', 'tex', 'markdown'] }

" CSV
" vim-polyglot
Plug 'chrisbra/csv.vim', { 'for': 'csv' }

" c/cpp
" vim-polyglot

" Python
" vim-polyglot
Plug 'jmcantrell/vim-virtualenv', { 'for': 'python' }

" Elm
" vim-polyglot
Plug 'ElmCast/elm-vim', { 'for': 'elm' }

" Haskell
" vim-polyglot
Plug 'eagletmt/neco-ghc', { 'for': 'haskell' }

" Vim script
" vim-polyglot
Plug 'IngoHeimbach/neco-vim', { 'for': 'vim' }

call plug#end()

" filetype plugin indent on " enable detection, plugins and indenting in one step
