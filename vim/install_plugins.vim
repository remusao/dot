" Enable vim-plug
filetype off

call plug#begin('~/.local/share/nvim/plugged')

" Linting
Plug 'dense-analysis/ale'

" Autocomplete
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --ts-completer --rust-completer' }
Plug 'SirVer/ultisnips' " Snippets engine
Plug 'honza/vim-snippets' " Actual snippets

" Mostly for history search
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive' " Git integration in Vim
Plug 'junegunn/gv.vim' " Git commit viewer

" Fuzzy search
Plug 'ctrlpvim/ctrlp.vim' " Fuzzy file searching from Vim
Plug 'nixprime/cpsm', { 'do': 'env PY3=ON ./install.sh' }

" Utilities
Plug 'ntpeters/vim-better-whitespace' " Highlight and strip trailing whitespaces
Plug 'mg979/vim-visual-multi'
Plug 'jiangmiao/auto-pairs'
Plug 'editorconfig/editorconfig-vim' " Check .editorconfig settings

" Colors
Plug 'nanotech/jellybeans.vim' " The only theme I ever liked...
Plug 'vim-airline/vim-airline' " Vim powerline
Plug 'vim-airline/vim-airline-themes' " Themes for powerline
Plug 'ap/vim-css-color',  {'for': ['css', 'less', 'sass', 'html', 'scss']}

" Notes
Plug 'xolox/vim-notes', { 'for': ['notes'], 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': ['notes'], 'on': 'Note' }     " Dependency of vim-notes

" Languages
" let g:polyglot_disabled = ['html.plugin', 'python.plugin', 'javascript.plugin', 'rust.plugin', 'svelte.plugin', 'typescript.plugin', 'yaml.plugin', 'json.plugin', 'css.plugin', 'autoindent']
" Plug 'sheerun/vim-polyglot' " Huge language pack
Plug 'rust-lang/rust.vim'

Plug 'hashivim/vim-vagrant', { 'for': ['ruby'] }
Plug 'lervag/vimtex', { 'for': ['tex'] }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

Plug 'github/copilot.vim'

" This seems very slow...
" Plug 'nvim-treesitter/nvim-treesitter-context'

" Plug 'folke/which-key.nvim'
" Plug 'tweekmonster/startuptime.vim'

call plug#end()

" filetype plugin indent on " enable detection, plugins and indenting in one step
