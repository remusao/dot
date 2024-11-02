""" Syntax Coloration
syntax enable
syntax on
set t_Co=256
let g:enable_bold_font = 1
set background=dark
colorscheme jellybeans
let g:jellybeans_use_lowcolor_black = 0

" lua << EOF
"   require("themer").setup({
" 	  colorscheme = "jellybeans",
"     term_colors = true,
" 	  styles = {
"       variable = { fg = "#c6b6ee" },
" 	  },
" 	})
" EOF
