""" Additionnal Mappings
nnoremap ; :
nnoremap <silent> ./ :nohlsearch<CR>

tnoremap <Esc> <C-\><C-n>

" Make these commonly mistyped commands still work
command! WQ wq
command! Wq wq
command! Wqa wqa
command! W w
command! Q q

" open help in a new tab
cabbrev help tab help

" Make navigating long, wrapped lines behave like normal lines (excluding
" operator-pending mode, so d2k still deletes by real lines).
nnoremap <silent> k gk
nnoremap <silent> j gj
nnoremap <silent> 0 g0
nnoremap <silent> $ g$
nnoremap <silent> ^ g^
nnoremap <silent> _ g_
xnoremap <silent> k gk
xnoremap <silent> j gj
xnoremap <silent> 0 g0
xnoremap <silent> $ g$
xnoremap <silent> ^ g^
xnoremap <silent> _ g_
