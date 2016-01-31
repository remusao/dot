""" Syntax Coloration
syntax on
set background=dark
set t_Co=256
" using Inconsolata font in gvim
set anti enc=utf-8
if has("gui_running")
    let g:solarized_termcolors=256
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized " Load a colorscheme"
    set guifont=Inconsolata\ Medium\ 16
    set guioptions-=m  "remove menu bar
    set guioptions-=T  "remove toolbar
    set guioptions-=r  "remove right-hand scroll bar
    set guioptions-=L  "remove left-hand scroll bar
else
    colorscheme jellybeans
    hi Normal ctermbg=NONE
endif
