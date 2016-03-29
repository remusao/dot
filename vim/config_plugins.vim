"" --- CONFIGURE PLUGINS --- ""

" {{{3 neocomplete
" neocomplete (non-cache version, works faster, need lua)
" https://github.com/Shougo/neocomplete.vim.git
" Disable AutoComplPop
let g:acp_enableAtStartup = 0
let g:neocomplete#enable_at_startup = 1
" Use smartcase
let g:neocomplete#enable_smart_case = 1
let g:neocomplete#enable_auto_select = 1
" Set minimum syntax keyword length.
let g:neocomplete#sources#syntax#min_keyword_length = 2
let g:neocomplete#auto_completion_start_length = 2
let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'
" increase limit for tag cache files
let g:neocomplete#sources#tags#cache_limit_size = 16777216 " 16MB
let g:neocomplete#enable_fuzzy_completion = 0

" Define dictionary.
let g:neocomplete#sources#dictionary#dictionaries = {
      \ 'default' : '',
      \ 'vimshell' : '~/.vim/.cache/vimshell_hist',
      \ 'scheme' : '~/.vim/.cache/gosh_completions'
      \ }

" Define keyword.
if !exists('g:neocomplete#keyword_patterns')
  let g:neocomplete#keyword_patterns = {}
endif
let g:neocomplete#keyword_patterns['default'] = '\h\w*'
" set cache dir
let g:neocomplete#data_directory = '~/.vim/.cache/neocomplete'

" Plugin key-mappings.
inoremap <expr><C-g>     neocomplete#undo_completion()
inoremap <expr><C-l>     neocomplete#complete_common_string()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return (pumvisible() ? "\<C-y>" : "" ) . "\<CR>"
  " For no inserting <CR> key.
  "return pumvisible() ? "\<C-y>" : "\<CR>"
endfunction
" <TAB>: completion.
"inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
" Close popup by <Space>.
" inoremap <expr><Space> pumvisible() ? "\<C-y>" : "\<Space>"

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=jedi#completions
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

" Key bindings
inoremap <expr><CR>  pumvisible() ? neocomplete#close_popup() : "\<CR>"
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><BS>  pumvisible() ? neocomplete#smart_close_popup()."\<C-h>" : "\<BS>"
inoremap <expr><C-y>  neocomplete#close_popup()
inoremap <expr><C-c>  neocomplete#cancel_popup()


" ----- ghc-mod -----
"
map <silent> tw :GhcModTypeInsert<CR>
map <silent> ts :GhcModSplitFunCase<CR>
map <silent> tq :GhcModType<CR>
map <silent> te :GhcModTypeClear<CR>

hi ghcmodType ctermbg=yellow
let g:ghcmod_type_highlight = 'ghcmodType'


" ----- Raimondi/delimitMate settings -----
"
let delimitMate_expand_cr = 1
augroup mydelimitMate
 au!
 au FileType markdown let b:delimitMate_nesting_quotes = ["`"]
 au FileType tex let b:delimitMate_quotes = ""
 au FileType tex let b:delimitMate_matchpairs = "(:),[:],{:},`:'"
 au FileType python let b:delimitMate_nesting_quotes = ['"', "'"]
augroup END

" ----- kien/ctrlp settings -----
"
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
if executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor
  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
endif

" ----- airblade/vim-gitgutter settings -----
" Required after having changed the colorscheme
hi clear SignColumn
" In vim-airline, only display "hunks" if the diff is non-zero
let g:airline#extensions#hunks#non_zero_only = 1


" ----- jistr/vim-nerdtree-tabs -----
" Open/close NERDTree Tabs with \t
nmap <silent> <leader>t :NERDTreeTabsToggle<CR>

" To have NERDTree always open on startup
let g:nerdtree_tabs_open_on_console_startup = 0
" open nerdtree if vim starts up with no files, but not focus on it
augroup OpenNerdTree
  autocmd!
  autocmd VimEnter * if !argc() | NERDTree | endif
  autocmd VimEnter * if !argc() | wincmd p | endif
augroup END
" close vim if the only window left is nerdtree
autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

let NERDTreeWinPos = "right"
let NERDTreeShowHidden = 0
let NERDTreeIgnore = ['\.pyc$', '\.swp$']

" ----- bling/vim-airline settings -----
set laststatus=2
let g:airline_detect_paste=1
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1

" ----- scrooloose/syntastic settings -----
let g:syntastic_python_checkers = ['pylint']
let g:syntastic_haskell_checkers = ["hdevtools", "hlint"]
let g:syntastic_haskell_hdevtools_args = '-g -Wall'
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_aggregate_errors = 1
let g:syntastic_error_symbol = '✘'

let g:syntastic_cpp_compiler = 'g++'
let g:syntastic_cpp_compiler_options = ' -std=c++11 -Wall -Wextra'

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

augroup mySyntastic
    au!
    au FileType tex let b:syntastic_mode = "passive"
augroup END

"" Julia
let g:julia_latex_to_unicode = 0
let g:latex_to_unicode_tab = 0

"" vim-markdown
let g:vim_markdown_folding_disabled=1

" Neco-ghc
let g:necoghc_enable_detailed_browse = 1
let g:haskellmode_completion_ghc = 0

" Neosnippet
" SuperTab like snippets behavior.
" imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
"     \ "\<Plug>(neosnippet_expand_or_jump)"
"     \: pumvisible() ? "\<C-n>" : "\<TAB>"
" smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
"     \ "\<Plug>(neosnippet_expand_or_jump)"
"     \: "\<TAB>"

nmap <silent> F :BufExplorer<CR>

let g:bufExplorerDisableDefaultKeyMapping=1 " Disable mapping.
let g:bufExplorerDefaultHelp=0       " Do not show default help.
let g:bufExplorerShowRelativePath=1  " Show relative paths.
let g:bufExplorerSortBy='mru'        " Sort by most recently used.
let g:bufExplorerSplitRight=0        " Split left.
let g:bufExplorerSplitVertical=1     " Split vertically.
let g:bufExplorerUseCurrentWindow=1  " Open in new window.
autocmd BufWinEnter \[Buf\ List\] setl nonumber

" clang-complete {{{
let g:clang_use_library=1
let g:clang_library_path = "/usr/lib/llvm-3.4/lib/"
let g:clang_snippets = 0
let g:clang_user_options = '-std=c++11'
" to work with noecomplete
if !exists('g:neocomplete#force_omni_input_patterns')
      let g:neocomplete#force_omni_input_patterns = {}
endif
let g:neocomplete#force_omni_input_patterns.c =
      \ '[^.[:digit:] *\t]\%(\.\|->\)\w*'
let g:neocomplete#force_omni_input_patterns.cpp =
      \ '[^.[:digit:] *\t]\%(\.\|->\)\w*\|\h\w*::\w*'
let g:neocomplete#force_omni_input_patterns.objc =
      \ '\[\h\w*\s\h\?\|\h\w*\%(\.\|->\)'
let g:neocomplete#force_omni_input_patterns.objcpp =
      \ '\[\h\w*\s\h\?\|\h\w*\%(\.\|->\)\|\h\w*::\w*'
let g:clang_complete_auto = 0
let g:clang_auto_select = 0
let g:clang_omnicppcomplete_compliance = 0
let g:clang_make_default_keymappings = 0

" vim-python {{{
let python_highlight_all = 1

" vim LargeFile
let g:LargeFile = 50

" incsearch {{{
let g:incsearch#consistent_n_direction = 1

map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" jedi-vim {{{
autocmd FileType python setlocal omnifunc=jedi#completions
let g:jedi#completions_enabled = 0
let g:jedi#auto_vim_configuration = 0
let g:jedi#smart_auto_mappings = 0
let g:neocomplete#force_omni_input_patterns.python =
\ '\%([^. \t]\.\|^\s*@\|^\s*from\s.\+import \|^\s*from \|^\s*import \)\w*'

" vim-notes
let g:notes_directories = ['~/Dropbox/Notes']
let g:notes_suffix = '.md'
let g:notes_word_boundaries = 1
let g:notes_smart_quotes = 1
