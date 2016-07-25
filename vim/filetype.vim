""""""""""""""""""""""""""""""""""""""""""""""
" File: filetype.vim
" Brief: filetype detection for vim configuration

" Creation Date: 13-02-2012
" Last Modified: Mon 09 Feb 2015 04:58:24 PM CET

" Author: Olivier Querné <o.querne@gmail.com>

""""""""""""""""""""""""""""""""""""""""""""""
" Global

autocmd BufNewFile,BufRead */.git/COMMIT_EDITMSG setlocal filetype=notes

augroup filetypedetect
  au BufNewFile,BufRead *.c,*.h                             setf c
  au BufNewFile,BufRead *.hcc,*.hh,*.hpp,*.hxx,*.cc,*.cpp   set filetype=cpp
  au BufNewFile,BufRead *.hs                                set filetype=haskell
  au BufNewFile,BufRead *.jl                                set filetype=julia
  au BufNewFile,BufRead *.jsm,*.js,*.es                     set filetype=javascript
  au BufRead,BufNewFile *.aasm                              set filetype=asm
  au BufRead,BufNewFile *.ll,*.yy                           set filetype=cpp
  au BufRead,BufNewFile *.mak,*.mako                        set filetype=mako
  au BufRead,BufNewFile *.md                                set filetype=markdown
  au BufRead,BufNewFile *.py                                set filetype=python
  au BufRead,BufNewFile *.s                                 set filetype=mips
  au BufRead,BufNewFile *.txt                               set filetype=txt
  au BufRead,BufNewFile *httpd*.conf                        set filetype=apache "Apache config files
  au BufRead,BufNewFile .htaccess                           set filetype=apache "htaccess files
  au! BufRead,BufNewFile *.json                             set filetype=json
augroup END

augroup Binary
  au!
  au BufReadPre  *.o,out,*.obj,*.a,*.so,*.exe,*.bin let &bin=1
  au BufReadPost *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin if &bin | %!xxd
  au BufReadPost *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin set ft=xxd | endif
  au BufWritePre *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin if &bin | %!xxd -r
  au BufWritePre *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin endif
  au BufWritePost *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin if &bin | %!xxd
  au BufWritePost *.o,*.out,*.obj,*.a,*.so,*.exe,*.bin set nomod | endif
augroup END

au BufNewFile,BufRead *todo,*TODO       set ft=wtodo

" CSV plugin
if exists("did_load_csvfiletype")
  finish
endif
let did_load_csvfiletype=1

augroup filetypedetect
  au! BufRead,BufNewFile *.csv,*.datsetfiletype csv
augroup END
