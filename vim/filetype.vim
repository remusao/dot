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
  au BufNewFile,BufRead Dockerfile*                         set filetype=dockerfile
  au BufNewFile,BufRead Jenkinsfile*                        set filetype=groovy
  au BufRead,BufNewFile *.aasm                              set filetype=asm
  au BufRead,BufNewFile *.mak,*.mako                        set filetype=mako
  au BufRead,BufNewFile *.s                                 set filetype=mips
  au BufRead,BufNewFile *.txt                               set filetype=txt
  au BufRead,BufNewFile *httpd*.conf                        set filetype=apache "Apache config files
  au BufRead,BufNewFile .htaccess                           set filetype=apache "htaccess files
  au BufRead,BufNewFile *.note                              set filetype=notes
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
