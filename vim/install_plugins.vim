" Enable vim-plug
filetype off

call plug#begin('~/.local/share/nvim/plugged')

" Linting
Plug 'w0rp/ale'

" Autocomplete
Plug 'Valloric/YouCompleteMe', { 'commit': 'b0f18804f3c85eab6bb2912ee3f2f3d2b238404a', 'do': './install.py --ts-completer --rust-completer' }
Plug 'SirVer/ultisnips'     " Snippets engine
Plug 'honza/vim-snippets'   " Actual snippets

Plug 'airblade/vim-gitgutter'           " Show git diff in Vim
Plug 'tpope/vim-fugitive'               " Git integration in Vim

" Fuzzy search
Plug 'ctrlpvim/ctrlp.vim'               " Fuzzy file searching from Vim
Plug 'nixprime/cpsm', { 'do': 'env PY3=ON ./install.sh' }
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

Plug 'ntpeters/vim-better-whitespace'   " Highlight and strip trailing whitespaces
Plug 'terryma/vim-multiple-cursors'     " Multi cursors
Plug 'mhinz/vim-hugefile'               " Read huge files efficiently

" Colors
Plug 'nanotech/jellybeans.vim'          " The only theme I ever liked...
Plug 'vim-airline/vim-airline'          " Vim powerline
Plug 'vim-airline/vim-airline-themes'   " Themes for powerline

" Notes
Plug 'xolox/vim-notes', { 'for': 'notes', 'on': 'Note' }    " Managing notes in vim
Plug 'xolox/vim-misc', { 'for': 'notes', 'on': 'Note' }     " Dependency of vim-notes

" Terraform
Plug 'hashivim/vim-terraform', { 'for': ['terraform'] }

Plug 'jiangmiao/auto-pairs'

Plug 'editorconfig/editorconfig-vim' " Check .editorconfig settings

" Languages support
Plug 'sheerun/vim-polyglot' " Huge language pack

" Language Client Protocol (not needed with Ale)
" Plug 'autozimu/LanguageClient-neovim', {
"     \ 'branch': 'next',
"     \ 'do': './install.sh'
"     \ }

" Plug 'Shougo/neco-syntax'

" C/C++
" vim-polyglot
" Plug 'zchee/deoplete-clang', { 'for': ['c', 'cpp'] }

" Javascript
" vim-polyglot
" Plug 'carlitux/deoplete-ternjs', { 'for': ['javascript', 'javascript.jsx'] }

" Typescript
" vim-polyglot
Plug 'HerringtonDarkholme/yats.vim', { 'for': 'typescript' }
" Plug 'mhartington/nvim-typescript', {'for': 'typescript', 'build': './install.sh' }

" CSS
" vim-polyglot
Plug 'gorodinskiy/vim-coloresque',  {'for': ['css', 'less', 'sass', 'html']}

" Rust
" vim-polyglot

" Markdown
" vim-polyglot
Plug 'junegunn/goyo.vim',           {'for': ['latex', 'tex', 'markdown']}
Plug 'plasticboy/vim-markdown',     {'for': ['latex', 'tex', 'markdown']}

" Latex
" vim-polyglot
Plug 'lervag/vimtex',               { 'for': ['latex', 'tex', 'markdown'] }

" CSV
" vim-polyglot
Plug 'chrisbra/csv.vim',            { 'for': 'csv' }

" Python
" vim-polyglot
Plug 'jmcantrell/vim-virtualenv',   { 'for': 'python' }
" Plug 'zchee/deoplete-jedi', { 'for': 'python' }

" Elm
" vim-polyglot
" Plug 'pbogut/deoplete-elm',          { 'for': 'elm'}

" Haskell
" vim-polyglot: haskell-vim
" Plug 'eagletmt/neco-ghc',           { 'for': 'haskell' }
Plug 'parsonsmatt/intero-neovim',   { 'for': 'haskell' }

" Plug 'alx741/vim-hindent',          { 'for': 'haskell' }
" Plug 'alx741/vim-stylishask',       { 'for': 'haskell' }

" Go
" vim-polyglot
Plug 'fatih/vim-go',                { 'for': 'go' }

" Vim script
" vim-polyglot
Plug 'IngoHeimbach/neco-vim',       { 'for': 'vim' }

" Zsh
" Plug 'zchee/deoplete-zsh', { 'for': ['zsh', 'sh', 'bash'] }

" Julia
Plug 'JuliaEditorSupport/julia-vim', { 'for': 'julia' }

call plug#end()

" filetype plugin indent on " enable detection, plugins and indenting in one step
