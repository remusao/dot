" Enable vim-plug
call plug#begin('~/.local/share/nvim/plugged')

" Linting + fixing
Plug 'dense-analysis/ale'

" LSP configs catalog (used with built-in vim.lsp.config / vim.lsp.enable)
Plug 'neovim/nvim-lspconfig'

" Mostly for history search
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive' " Git integration in Vim
Plug 'junegunn/gv.vim' " Git commit viewer

" Fuzzy search (fzf + fzf.vim, configured in config_plugins.vim)

" Utilities
Plug 'ntpeters/vim-better-whitespace' " Highlight and strip trailing whitespaces
Plug 'mg979/vim-visual-multi'
Plug 'windwp/nvim-autopairs'

" Colors
Plug 'nanotech/jellybeans.vim' " The only theme I ever liked...
Plug 'vim-airline/vim-airline' " Vim powerline
Plug 'vim-airline/vim-airline-themes' " Themes for powerline
Plug 'ap/vim-css-color',  {'for': ['css', 'less', 'sass', 'html', 'scss', 'vim']}

" Notes
Plug 'xolox/vim-notes', { 'for': ['notes'], 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': ['notes'], 'on': 'Note' }     " Dependency of vim-notes

" Languages
Plug 'rust-lang/rust.vim'
Plug 'lervag/vimtex', { 'for': ['tex'] }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate', 'branch': 'main'}

Plug 'github/copilot.vim'

call plug#end()
