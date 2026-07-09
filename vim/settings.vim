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
set noshowmode        " lualine shows the mode
set smartcase
set ignorecase
set nomodeline
set mouse=a
set linebreak
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

set ttimeoutlen=25    " wait for terminal key-codes; 25ms survives SSH latency, no perceptible Esc lag

" Disable modifyOtherKeys for urxvt which doesn't support it
if $TERM =~# 'rxvt' || $COLORTERM =~# 'rxvt'
  autocmd VimEnter * ++once call chansend(v:stderr, "\x1b[>4;0m")
endif
set breakindent

set wildignore=*.swp,*.bak,*.pyc,*.class,*.so,*.zip,.git,.cabal-sandbox
set completeopt=menu,menuone,noselect,popup
set pumheight=15      " Cap completion popup height (LSP can otherwise fill the screen)
set clipboard+=unnamedplus
set switchbuf=useopen,uselast
set wildmode=list:longest,full

" --- modern niceties (nvim 0.11+, all zero-overhead) ---
set signcolumn=yes    " stable gutter, no jitter as signs/diagnostics appear
set splitkeep=screen  " keep text position when opening/closing splits
set confirm           " prompt to save instead of erroring on :q with changes
set virtualedit=block " rectangular visual-block selections past end-of-line
set winborder=rounded " default border for floating windows (hover, diagnostics)
set cursorline           " mark the current line...
set cursorlineopt=number " ...number column only: locate the cursor, no full-line band (cheap redraw for urxvt)
set diffopt+=linematch:60 " align changed lines within diff hunks (upstream-recommended)
set jumpoptions+=view     " restore scroll position when jumping the jumplist (<C-o>/<C-i>)
