" This must be first, because it changes other options as side effect
set nocompatible " Break Vi backward compatibility


" Enable Vundle
filetype off
set rtp+=~/.vim/bundle/vundle
call vundle#rc()

" let Vundle manage Vundle, required
Bundle 'gmarik/vundle'

Bundle 'tpope/vim-fugitive'
Bundle 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Bundle 'altercation/vim-colors-solarized'
Bundle 'scrooloose/syntastic'
Bundle 'plasticboy/vim-markdown'
Bundle 'Valloric/YouCompleteMe'
Bundle 'kien/ctrlp.vim'
<<<<<<< HEAD
Bundle 'JuliaLang/julia-vim'
=======
Bundle 'scooloose/nerdtree'
Bundle 'JuliaLang/julia-vim'

let g:julia_latex_to_unicode = 0
>>>>>>> f3cdf49f927bf660fb409b419e5471b71ab336dc

filetype plugin indent on " enable detection, plugins and indenting in one step
set background=dark

" Set encoding
set encoding=utf-8
set fileencoding=utf-8

""" Syntax Coloration
syntax on
set background=dark
set t_Co=256
autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
colorscheme jellybeans
hi Normal ctermbg=NONE
" using Source Code Pro
set anti enc=utf-8
set guifont=Source\ Code\ Pro\ 13

"" --- CONFIGURE PLUGINS --- ""
"" Julia
let g:latex_to_unicode_tab = 0
"" vim-markdown
let g:vim_markdown_folding_disabled=1

"" Syntastic
let g:syntastic_python_checkers = ['pylint']

"" YouCompleteMe
let g:ycm_min_num_of_chars_for_completion = 1
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_autoclose_preview_window_after_insertion = 1

"" ctrlp.vim
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

"" Powerline
let g:Powerline_symbols = 'fancy'

"python remove trailing whitespace
autocmd BufWritePre *.py normal m`:%s/\s\+$//e ``
""python highlighting extras
let python_highlight_all = 1
set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux

" General options
set tabstop=4 " a tab is four spaces
set softtabstop=4 " when hitting <BS>, pretend like a tab is removed, even if spaces
set shiftwidth=4 " number of spaces to use for autoindenting
set autoindent " always set autoindenting on
set backspace=indent,eol,start " allow backspacing over everything in insert mode
set copyindent " copy the previous indentation on autoindenting
set expandtab
set hidden
set hlsearch is " highlight search terms
set ignorecase " ignore case when searching
set incsearch " show search matches as you type
set laststatus=2
if v:version >= 730
    set undofile " keep a persistent backup file
    set undodir=~/.vim/.undo,~/tmp,/tmp
endif
set nobackup
set noswapfile
set directory=~/.vim/.tmp,~/tmp,/tmp " store swap files in one of these directories
set nowrap " don't wrap lines
set number " always show line numbers
set ruler
set shiftround " use multiple of shiftwidth when indenting with '<' and '>'
set showcmd
set showmatch " set show matching parenthesis
set smartcase " ignore case if search pattern is all lowercase, " case-sensitive otherwise
set smartindent
set smarttab " insert tabs on the start of a line according to shiftwidth, not tabstop
set wildignore=*.swp,*.bak,*.pyc,*.class " Ignore this extension in file searching
" Complete options (disable preview scratch window)
set completeopt=menu,menuone,longest
" Limit popup menu height
set pumheight=15
set lazyredraw " don't update the display while executing macros
set switchbuf=useopen " reveal already opened files from the
" quickfix window instead of opening new
" buffers
set wildmenu " make tab completion for files/buffers act like bash
set wildmode=list:full " show a list when pressing tab and complete
" first full match
set cursorline " underline the current line, for quick orientation
set title

"highlight WhitespaceEOL ctermbg=red guibg=red
"match WhitespaceEOL /\s\+$/
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$\| \+\ze\t/

""" Additionnal Mappings
nnoremap ; :
nmap <silent> ./ :nohlsearch<CR>

""" Define map <Leader>
let mapleader = ","

""" --- PLUGINS OPTIONS ---

" Strip all trailing whitespace from a file, using ,w
nnoremap ,W :%s/\s\+$//<CR>:let @/=''<CR>



" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

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


"Limit the width of text for mutt to 80 columns
au BufRead /tmp/mutt-* set tw=80

     
" Git commit preference
autocmd Filetype gitcommit setlocal spell textwidth=72
