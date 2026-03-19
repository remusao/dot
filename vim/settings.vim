" Python path with neovim package installed
let g:python3_host_prog = '/home/remi/.virtualenvs/neovim3/bin/python'

" Disable unused providers
let g:loaded_ruby_provider = 0
let g:loaded_perl_provider = 0

set title
set number
set noshowmode        " airline shows the mode
set gdefault          " global flag for search and replace
set cursorline!       " disable cursor line highlight
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
set breakindent

set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip,.git,.cabal-sandbox
set completeopt=menu,menuone,longest
set clipboard+=unnamedplus
set switchbuf=useopen
set wildmode=list:longest,full

autocmd Filetype gitcommit setlocal spell textwidth=80
