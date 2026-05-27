" ~/.vim is where this config lives (sourced explicitly by vimrc); also put it
" on the runtimepath so ftplugin/ and after/ftplugin/ are auto-loaded.
set runtimepath^=~/.vim
set runtimepath+=~/.vim/after

" Must be set before any <Leader> mapping (config_plugins.vim defines several
" and is sourced before mappings.vim).
let mapleader = ","

" Python path with neovim package installed
let g:python3_host_prog = '/home/remi/.virtualenvs/neovim3/bin/python'

" Disable unused providers
let g:loaded_ruby_provider = 0
let g:loaded_perl_provider = 0
let g:loaded_node_provider = 0

set title
set number
set noshowmode        " airline shows the mode
set gdefault          " global flag for search and replace
set smartcase
set ignorecase
set inccommand=nosplit
set nomodeline
set showmatch
set mouse=a
set wrap linebreak nolist
set termguicolors
set updatetime=250    " faster CursorHold events (default 4000)

" Persistent undo
call mkdir(expand('~/.config/nvim/backups'), 'p')
set undodir=~/.config/nvim/backups
set undofile
set undolevels=10000

set colorcolumn=80

" Indentation
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set shiftround

set nofoldenable

" Splits
set splitright
set splitbelow

set ttimeoutlen=10

" Disable modifyOtherKeys for urxvt which doesn't support it
if $TERM =~# 'rxvt' || $COLORTERM =~# 'rxvt'
  " Disable BCE so ctermbg doesn't flicker on first paint (Debian #747633)
  set t_ut=
  autocmd VimEnter * ++once call chansend(v:stderr, "\x1b[>4;0m")
endif
set breakindent

set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip,.git,.cabal-sandbox
set completeopt=menu,menuone,noselect,popup
set pumheight=15      " Cap completion popup height (LSP can otherwise fill the screen)
set clipboard+=unnamedplus
set switchbuf=useopen
set wildmode=list:longest,full
