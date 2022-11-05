" Enable vim-plug
filetype off

call plug#begin('~/.local/share/nvim/plugged')

" Linting
Plug 'dense-analysis/ale'

" Autocomplete
" Plug 'ycm-core/YouCompleteMe', { 'commit': '4117a99861b537830d717c3113e3d584523bc573', 'do': './install.py --ts-completer --rust-completer' }
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --ts-completer --rust-completer' }
Plug 'SirVer/ultisnips' " Snippets engine
Plug 'honza/vim-snippets' " Actual snippets

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
Plug 'gorodinskiy/vim-coloresque',  {'for': ['css', 'less', 'sass', 'html']}

" Notes
Plug 'xolox/vim-notes', { 'for': ['notes'], 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': ['notes'], 'on': 'Note' }     " Dependency of vim-notes

" Languages
let g:polyglot_disabled = ['python.plugin', 'javascript.plugin', 'typescript.plugin', 'rust.plugin', 'css.plugin', 'html.plugin', 'json.plugin', 'yaml.plugin', 'autoindent']
Plug 'sheerun/vim-polyglot' " Huge language pack

Plug 'hashivim/vim-vagrant'
Plug 'lervag/vimtex'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

call plug#end()

" filetype plugin indent on " enable detection, plugins and indenting in one step
