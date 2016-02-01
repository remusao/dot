""" Syntax Coloration
syntax enable
set background=dark
set t_Co=256
set anti enc=utf-8
colorscheme jellybeans
let g:jellybeans_use_lowcolor_black = 0
if has("gui_running")
    colorscheme solarized
    set guifont=Inconsolata\ Medium\ 16
    set guioptions-=m  "remove menu bar
    set guioptions-=T  "remove toolbar
    set guioptions-=r  "remove right-hand scroll bar
    set guioptions-=L  "remove left-hand scroll bar
endif
