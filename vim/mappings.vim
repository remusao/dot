""" Additionnal Mappings
nnoremap ; :

tnoremap <Esc> <C-\><C-n>

" Make these commonly mistyped commands still work
command! WQ wq
command! Wq wq
command! Wqa wqa
command! W w
command! Q q

" open help in a new tab (guarded so it only fires as the first cmdline word,
" not inside :s/help/... or :verbose help ...)
cnoreabbrev <expr> help getcmdtype() == ':' && getcmdpos() <= 5 ? 'tab help' : 'help'

" In the wildmenu popup, <Up>/<Down> navigate matches (<Tab>/<C-p>/<C-n> also do);
" otherwise they keep their normal cmdline-history behaviour.
cnoremap <expr> <Up>   wildmenumode() ? "\<C-p>" : "\<Up>"
cnoremap <expr> <Down> wildmenumode() ? "\<C-n>" : "\<Down>"

" Navigate wrapped lines as display lines, but keep counts real (5j = 5 real
" lines, so relative jumps and macros still work); operator-pending is left
" alone (d2k deletes by real lines).
nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'
xnoremap <expr> j v:count ? 'j' : 'gj'
xnoremap <expr> k v:count ? 'k' : 'gk'
nnoremap <silent> 0 g0
nnoremap <silent> $ g$
nnoremap <silent> ^ g^
xnoremap <silent> 0 g0
xnoremap <silent> $ g$
xnoremap <silent> ^ g^
