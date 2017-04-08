" Enable neobundle
filetype off

set runtimepath+=~/.vim/bundle/dein.vim/

if dein#load_state('~/.vim/bundle/')
  call dein#begin('~/.vim/bundle/')

  " Let dein manage dein
  " Required:
  call dein#add('Shougo/dein.vim')

  " linting
  call dein#add('w0rp/ale')

  " Autocomplete
  call dein#add('Shougo/deoplete.nvim')
  call dein#add('ervandew/supertab')

  call dein#add('Raimondi/delimitMate')             " Automatic closing of quotes, parenthesis, brackets, etc.
  call dein#add('airblade/vim-gitgutter')           " Show git diff in Vim

  " Fuzzy search
  call dein#add('ctrlpvim/ctrlp.vim')               " File searching from Vim
  call dein#add('junegunn/fzf',
    \{ 'build': './install --bin' })
  call dein#add('junegunn/fzf.vim')

  call dein#add('ntpeters/vim-better-whitespace')   " Highlight and strip trailing whitespaces
  call dein#add('terryma/vim-multiple-cursors')     " Multi cursors
  call dein#add('vim-airline/vim-airline')          " Vim powerline
  call dein#add('vim-airline/vim-airline-themes')   " Themes for powerline
  call dein#add('xolox/vim-notes')                  " Managing notes in vim
  call dein#add('xolox/vim-misc')                   " Dependency of vim-notes
  call dein#add('mhinz/vim-hugefile')               " Read huge files efficiently

  " Colors
  call dein#add('nanotech/jellybeans.vim')          " The only theme I ever liked...

  " Javascript
  " vim-polyglot
  call dein#add('carlitux/deoplete-ternjs',
    \{'on_ft': ['javascript']})
  call dein#add('ternjs/tern_for_vim',
    \{'on_ft': ['javascript'], 'build': 'npm install && npm install -g tern'})

  " Language support
  call dein#add('sheerun/vim-polyglot')             " Huge language pack

  " Rust
  " vim-polyglot

  " Markdown
  " vim-polyglot
  call dein#add('junegunn/goyo.vim',
    \{'on_ft': ['latex', 'tex', 'markdown']})
  call dein#add('plasticboy/vim-markdown',
    \{'on_ft': ['latex', 'tex', 'markdown']})

  " Latex
  call dein#add('poppyschmo/deoplete-latex',
    \{'on_ft': ['latex', 'tex', 'markdown']})

  " CSV
  call dein#add('chrisbra/csv.vim',
    \{'on_ft': ['csv']})

  " c/cpp
  " vim-polyglot
  call dein#add('zchee/deoplete-clang',
    \{'on_ft': ['c', 'cpp']})

  " Python
  " vim-polyglot
  call dein#add('davidhalter/jedi-vim',
    \{'on_ft': ['python', 'python3']})
  call dein#add('zchee/deoplete-jedi',
    \{'on_ft': ['python', 'python3']})

  " Haskell
  " vim-polyglot
  call dein#add('dag/vim2hs',
    \{'on_ft': ['haskell']})
  call dein#add('eagletmt/neco-ghc',
    \{'on_ft': ['haskell']})

  call dein#end()
endif

filetype plugin indent on " enable detection, plugins and indenting in one step
