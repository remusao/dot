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
set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip,.git,.cabal-sandbox " Ignore this extension in file searching
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


" Set encoding
set encoding=utf-8
set fileencoding=utf-8


