if &compatible
    set nocompatible
endif

" Enable neobundle
filetype off
set runtimepath+=~/.vim/bundle/dein.vim/
call dein#begin(expand('~/.cache/dein'))
call dein#add('Shougo/dein.vim')

call dein#add('Shougo/vimproc.vim',
    \{'build': {'linux': 'make'}})

" General addons
call dein#add('MarcWeber/vim-addon-mw-utils')
call dein#add('xolox/vim-misc')
call dein#add('tomtom/tlib_vim')
call dein#add('Shougo/unite.vim')

call dein#add('Raimondi/delimitMate') " Automatic closing of quotes, parenthesis, brackets, etc.
call dein#add('Shougo/neocomplete.vim') " Auto-completion engine
call dein#add('Shougo/vimshell.vim') " Shell integration in Vim
call dein#add('airblade/vim-gitgutter') " Show git diff in Vim
call dein#add('bling/vim-airline') " Vim powerline
call dein#add('ctrlpvim/ctrlp.vim') " File searching from Vim
call dein#add('godlygeek/tabular') " Align stuff
call dein#add('jistr/vim-nerdtree-tabs') " :NERDTreeTabsToggle to display in all tabs
call dein#add('jlanzarotta/bufexplorer')
call dein#add('ntpeters/vim-better-whitespace') " Highlight and strip trailing whitespaces
call dein#add('rking/ag.vim') " Silver searcher from Vim
call dein#add('scrooloose/nerdtree') " Nerdtree
call dein#add('scrooloose/syntastic') " Syntax checking
call dein#add('sheerun/vim-polyglot')
call dein#add('terryma/vim-multiple-cursors') " Multi cursors
call dein#add('tpope/vim-abolish')
call dein#add('tpope/vim-eunuch')
call dein#add('tpope/vim-repeat')
call dein#add('vim-airline/vim-airline')
call dein#add('vim-airline/vim-airline-themes')
call dein#add('xolox/vim-notes')
call dein#add('xolox/vim-shell')
call dein#add('vim-scripts/LargeFile')
call dein#add('haya14busa/incsearch.vim')
call dein#add('Konfekt/FastFold')

" Colors
call dein#add('altercation/vim-colors-solarized')
call dein#add('nanotech/jellybeans.vim')


" Markdown
call dein#add('plasticboy/vim-markdown',
    \{'on_ft': ['markdown']})


" CSV
call dein#add('chrisbra/csv.vim',
    \{'on_ft': ['csv']})


" c/cpp
call dein#add('Rip-Rip/clang_complete',
    \{'on_ft': ['c', 'cpp']})


" Python
call dein#add('hdima/python-syntax',
    \{'on_ft': ['python', 'python3']})
call dein#add('davidhalter/jedi-vim',
    \{'on_ft': ['python', 'python3']})


" Julia
call dein#add('JuliaLang/julia-vim')


" Haskell
call dein#add('dag/vim2hs',
    \{'on_ft': ['haskell']})
call dein#add('eagletmt/ghcmod-vim',
    \{'on_ft': ['haskell']})
call dein#add('eagletmt/neco-ghc',
    \{'on_ft': ['haskell']})

call dein#end()

" enable detection, plugins and indenting in one step
filetype plugin indent on

if dein#check_install()
    call dein#install()
endif
