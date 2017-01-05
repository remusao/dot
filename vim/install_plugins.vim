" Enable neobundle
filetype off
set runtimepath+=~/.vim/bundle/dein.vim/

if dein#load_state('~/.vim/bundle/')

  call dein#begin('~/.vim/bundle/')

  " Let dein manage dein
  " Required:
  call dein#add('Shougo/dein.vim')

  call dein#add('Shougo/vimproc.vim', {'build': 'make'})

  " General addons
  call dein#add('Shougo/unite.vim')
  call dein#add('MarcWeber/vim-addon-mw-utils')
  call dein#add('xolox/vim-misc')
  call dein#add('tomtom/tlib_vim')

  " linting
  if !has('nvim')
    call dein#add('vim-syntastic/syntastic')	" Syntax checking
    call dein#add('myint/syntastic-extras')
  else
    call dein#add('neomake/neomake')
  endif

  " Autocomplete
  if !has('nvim')
    call dein#add('Shougo/neocomplete.vim')	" Auto-completion engine
  else
    call dein#add('Shougo/deoplete.nvim')	" Auto-completion engine
    call dein#add('ervandew/supertab')
  endif

  call dein#add('Raimondi/delimitMate')	            " Automatic closing of quotes, parenthesis, brackets, etc.
  call dein#add('airblade/vim-gitgutter')	        " Show git diff in Vim
  call dein#add('bling/vim-airline')		        " Vim powerline
  call dein#add('ctrlpvim/ctrlp.vim')		        " File searching from Vim
  call dein#add('ntpeters/vim-better-whitespace')   " Highlight and strip trailing whitespaces
  call dein#add('rking/ag.vim')			            " Silver searcher from Vim
  call dein#add('sheerun/vim-polyglot')
  call dein#add('terryma/vim-multiple-cursors')     " Multi cursors
  call dein#add('tpope/vim-abolish')
  call dein#add('vim-airline/vim-airline')
  call dein#add('vim-airline/vim-airline-themes')
  call dein#add('xolox/vim-notes')
  call dein#add('xolox/vim-shell')
  call dein#add('mhinz/vim-hugefile')
  call dein#add('haya14busa/incsearch.vim')
  call dein#add('haya14busa/incsearch-fuzzy.vim')
  call dein#add('Konfekt/FastFold')
  call dein#add('editorconfig/editorconfig-vim')

  " Colors
  call dein#add('altercation/vim-colors-solarized')
  call dein#add('nanotech/jellybeans.vim')

  " Javascript
  " vim-polyglot
  call dein#add('pangloss/vim-javascript',
    \{'on_ft': ['javascript']})

  " Rust
  " vim-polyglot

  " Markdown
  " vim-polyglot

  " CSV
  call dein#add('chrisbra/csv.vim',
    \{'on_ft': ['csv']})

  " c/cpp
  call dein#add('Rip-Rip/clang_complete',
    \{'on_ft': ['c', 'cpp']})

  " Python
  " vim-polyglot
  call dein#add('davidhalter/jedi-vim',
    \{'on_ft': ['python', 'python3']})

  " Haskell
  call dein#add('dag/vim2hs',
    \{'on_ft': ['haskell']})
  call dein#add('eagletmt/ghcmod-vim',
    \{'on_ft': ['haskell']})
  call dein#add('eagletmt/neco-ghc',
    \{'on_ft': ['haskell']})

  call dein#end()
endif

filetype plugin indent on " enable detection, plugins and indenting in one step
