" Enable vim-plug
call plug#begin('~/.local/share/nvim/plugged')

" Linting + fixing
Plug 'dense-analysis/ale'

" LSP configs catalog (used with built-in vim.lsp.config / vim.lsp.enable)
Plug 'neovim/nvim-lspconfig'

" Completion engine + snippet library (fuzzy as-you-type; replaces YCM/native)
Plug 'saghen/blink.cmp', { 'tag': 'v1.*' }
Plug 'rafamadriz/friendly-snippets'

" Mostly for history search
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git
Plug 'lewis6991/gitsigns.nvim'
Plug 'tpope/vim-fugitive' " Git integration in Vim
Plug 'junegunn/gv.vim' " Git commit viewer

" Fuzzy search (fzf + fzf.vim, configured in config_plugins.vim)

" Utilities
Plug 'ntpeters/vim-better-whitespace' " Highlight and strip trailing whitespaces
Plug 'mg979/vim-visual-multi'
Plug 'windwp/nvim-autopairs'

" Colors + statusline
Plug 'nanotech/jellybeans.vim' " The only theme I ever liked...
Plug 'nvim-lualine/lualine.nvim' " Statusline (replaces vim-airline)
Plug 'ap/vim-css-color',  {'for': ['css', 'less', 'sass', 'html', 'scss', 'vim']}

" Notes
Plug 'xolox/vim-notes', { 'for': ['notes'], 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': ['notes'], 'on': 'Note' }     " Dependency of vim-notes

" Languages (rust.vim dropped: nvim 0.12 ships a newer built-in rust ftplugin/indent
" -- incl. :RustFmt/:RustTest/:Cargo -- so rust-analyzer + treesitter + ALE's rustfmt
" fixer cover the rest)
Plug 'lervag/vimtex', { 'for': ['tex'] }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate', 'branch': 'main'}

" AI completion (ghost-text; integrates with blink.cmp -- see config_plugins.vim)
Plug 'zbirenbaum/copilot.lua'

call plug#end()
