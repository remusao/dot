" Enable vim-plug
filetype off

call plug#begin('~/.local/share/nvim/plugged')

" Linting
Plug 'w0rp/ale'

" Autocomplete
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --ts-completer --rust-completer --clang-completer' }
Plug 'SirVer/ultisnips'     " Snippets engine
Plug 'honza/vim-snippets'   " Actual snippets

Plug 'airblade/vim-gitgutter'   " Show git diff in Vim
Plug 'tpope/vim-fugitive'       " Git integration in Vim
Plug 'junegunn/gv.vim'          " Git commit viewer

" Fuzzy search
Plug 'ctrlpvim/ctrlp.vim'               " Fuzzy file searching from Vim
Plug 'nixprime/cpsm', { 'do': 'env PY3=ON ./install.sh' }
" Plug 'srstevenson/vim-picker'

Plug 'ntpeters/vim-better-whitespace'   " Highlight and strip trailing whitespaces
Plug 'mg979/vim-visual-multi'     " Multi cursors
Plug 'mhinz/vim-hugefile'               " Read huge files efficiently

" Colors
Plug 'nanotech/jellybeans.vim'          " The only theme I ever liked...
Plug 'vim-airline/vim-airline'          " Vim powerline
Plug 'vim-airline/vim-airline-themes'   " Themes for powerline

" Notes
Plug 'xolox/vim-notes', { 'for': ['notes'], 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': ['notes'], 'on': 'Note' }     " Dependency of vim-notes

" Terraform
Plug 'hashivim/vim-terraform', { 'for': ['terraform'] }

Plug 'jiangmiao/auto-pairs'
" Plug 'tmsvg/pear-tree'

Plug 'editorconfig/editorconfig-vim' " Check .editorconfig settings

Plug 'kkoomen/vim-doge'

" Languages support
" Plug 'sheerun/vim-polyglot' " Huge language pack

" Toml
Plug 'cespare/vim-toml', { 'for': ['toml'] }

" JavaScript
Plug 'pangloss/vim-javascript', { 'for': ['javascript'] }
Plug 'MaxMEllon/vim-jsx-pretty', { 'for': ['javascriptreact'] }

" TypeScript
" vim-polyglot
Plug 'HerringtonDarkholme/yats.vim', { 'for': ['typescript', 'javascript'] }

" CSS
" vim-polyglot
Plug 'gorodinskiy/vim-coloresque',  {'for': ['css', 'less', 'sass', 'html']}

" Rust
" vim-polyglot
Plug 'rust-lang/rust.vim', {'for': ['rust']}

" Markdown
" vim-polyglot
Plug 'junegunn/goyo.vim',           {'for': ['latex', 'tex', 'markdown', 'goyo']}
Plug 'plasticboy/vim-markdown',     {'for': ['latex', 'tex', 'markdown']}

" Latex
" vim-polyglot
Plug 'lervag/vimtex',               { 'for': ['latex', 'tex', 'markdown'] }

" CSV
" vim-polyglot
Plug 'chrisbra/csv.vim',            { 'for': ['csv'] }

" Python
" vim-polyglot
Plug 'jmcantrell/vim-virtualenv',   { 'for': ['python'] }
Plug 'vim-python/python-syntax', { 'for': ['python'] }

" Elm
" vim-polyglot

" Haskell
" vim-polyglot: haskell-vim
Plug 'parsonsmatt/intero-neovim',   { 'for': ['haskell'] }

" Go
" vim-polyglot
" Plug 'fatih/vim-go',                { 'for': 'go' }

" Vim script
" vim-polyglot
Plug 'IngoHeimbach/neco-vim',       { 'for': ['vim'] }

" Zsh
" vim-polyglot

" Julia
" Plug 'JuliaEditorSupport/julia-vim', { 'for': 'julia' }

call plug#end()

" filetype plugin indent on " enable detection, plugins and indenting in one step
