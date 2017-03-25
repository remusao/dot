" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" Python path with neovim package installed
let g:python_host_prog = '/home/remi/.virtualenvs/neovim2/bin/python2'
let g:python3_host_prog = '/home/remi/.virtualenvs/neovim3/bin/python3'

set title           " Change terminal's title
set number          " show line numbers
set history=500     " keep 1000 lines of command line history
set showcmd         " display incomplete commands
set noshowmode      " disable showmode because of Powerline
set gdefault        " Set global flags for search and replace
set cursorline      " underline the current line, for quick orientation
set smartcase       " ignore case if search pattern is all lowercase, case-sensitive otherwise
set ignorecase      " ignore case when searching

"" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

set showmatch                          " set show matching parenthesis
set timeoutlen=1000 ttimeoutlen=200    "Reduce Command timeout for faster escape and O

" Set encoding
set encoding=utf-8
set fileencoding=utf-8
set fileformat=unix

set wrap                            " Wrap lines
set linebreak                       " Wrap lines at convenient points
set list
set lazyredraw                      " don't update the display while executing macros
set hidden                          " Hide buffers in background

" Disable automatic wrapping.
set textwidth=0

" Don't store swap files
set nobackup
set noswapfile
set nowb

" Reduce processing for syntax highlighting to make it less of a pain.
set synmaxcol=128
syntax sync minlines=256
syntax sync maxlines=500
set synmaxcol=400

" Persistent undo
silent !mkdir ~/.config/nvim/backups > /dev/null 2>&1
set undodir=~/.config/nvim/backups
set undofile

" Set the right margin.
set colorcolumn=80

" Automatically re-open files after they have changed without prompting.
" This can be a little more destructive, but a lot less annoying.
set autoread

" Indentation
set tabstop=4       " default to 4 spaces for a hard tab
set softtabstop=4   " default to 4 spaces for the soft tab
set shiftwidth=4    " for when <TAB> is pressed at the beginning of a line
set expandtab       " Expand tabs into spaces
set smartindent
set nofoldenable
set autoindent      " always set autoindenting on
set copyindent      " copy the previous indentation on autoindenting

" Completion
set wildmode=list:longest,full

" allow backspacing over everything in insert mode
set backspace=indent,eol,start
set ruler               " show the cursor position all the time
set incsearch           " do incremental searching
set splitright          " Vertical splits use right half of screen
set timeoutlen=100      " Lower ^[ timeout
set fillchars=fold:\ ,  " get rid of obnoxious '-' characters in folds
set tildeop             " use ~ to toggle case as an operator, not a motion

if exists('breakindent')
    set breakindent " Indent wrapped lines up to the same level
endif

set hlsearch is     " highlight search terms
set shiftround      " use multiple of shiftwidth when indenting with '<' and '>'
set smarttab        " insert tabs on the start of a line according to shiftwidth, not tabstop
set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip,.git,.cabal-sandbox " Ignore this extension in file searching

" Complete options (disable preview scratch window)
set completeopt=menu,menuone,longest

" Limit popup menu height
set pumheight=15
set switchbuf=useopen " reveal already opened files from the
" quickfix window instead of opening new buffers
"
set wildmenu " make tab completion for files/buffers act like bash

" first full match
set pastetoggle=<F12>

" Limit the width of text for mutt to 80 columns
au BufRead /tmp/mutt-* set tw=80

"" Git commit preference
autocmd Filetype gitcommit setlocal spell textwidth=80

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
