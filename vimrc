source ~/.vim/options.vim
source ~/.vim/install_plugins.vim
source ~/.vim/colorscheme.vim
source ~/.vim/config_plugins.vim
source ~/.vim/mappings.vim
source ~/.vim/filetype.vim

" Limit the width of text for mutt to 80 columns
au BufRead /tmp/mutt-* set tw=80

"" Git commit preference
autocmd Filetype gitcommit setlocal spell textwidth=72

"" In many terminal emulators the mouse works just fine, thus enable it.
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
