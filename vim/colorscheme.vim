""" Syntax Coloration
syntax enable
syntax on
set t_Co=256
let g:enable_bold_font = 1
set background=dark
colorscheme jellybeans
let g:jellybeans_use_lowcolor_black = 0
" colorscheme catppuccin-latte
" let g:airline_theme = 'catppuccin'
" lua << EOF
" require("catppuccin").setup({
"     integrations = {
"       gitgutter = true,
"       semantic_tokens = true,
"       nvimtree = true,
"       treesitter_context = true,
"       treesitter = true,
"       markdown = true,
"     }
" })
" EOF
