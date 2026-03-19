""" Syntax Coloration
let g:enable_bold_font = 1
set background=dark
colorscheme jellybeans
let g:jellybeans_use_lowcolor_black = 0

" Neovim 0.10+ compat: hi clear inside jellybeans.vim resets to the built-in
" default colorscheme (PR #26334). Most default TreeSitter links cascade
" correctly through jellybeans' base groups. Only override groups where the
" default behavior doesn't match jellybeans' intent.
if has('nvim-0.10')
  " @variable gets a direct guifg (#e0e2ea) from Neovim defaults instead of
  " a link — doesn't match jellybeans' Normal foreground (#e8e8d3).
  hi! link @variable            Normal

  " Modules/namespaces: default links to Structure (blue-cyan). Original
  " jellybeans regex syntax had no special module coloring — plain text.
  hi! link @module              Normal

  " Builtins: Neovim defaults link all *.builtin to Special (green #799d6a).
  " Original jellybeans had: Boolean→Constant, pythonBuiltin→Function, Type→Type.
  hi! link @constant.builtin    Constant
  hi! link @function.builtin    Function
  hi! link @type.builtin        Type

  " HTML/XML tags: jellybeans styles tags as Statement (blue), not Special.
  " htmlArg→Type in Vim's syntax; delimiters were part of htmlTag→Statement.
  hi! link @tag                 Statement
  hi! link @tag.attribute       Type
  hi! link @tag.delimiter       Statement

  " Import keywords: PreProc (cyan) to match Include tradition.
  hi! link @keyword.import      PreProc

  " URIs: Underlined has no fg color. Morning glory + underline.
  hi @string.special.url        guifg=#8fbfdc gui=underline
  hi! link @markup.link.url     @string.special.url

  " Markup: code blocks as String (green), list markers as Delimiter.
  hi! link @markup.raw          String
  hi! link @markup.list         Delimiter

  " Semantic diff — Neovim defaults are bright pastels, too harsh.
  hi! link Added                String
  hi! link Changed              Statement
  hi! link Removed              Constant

  " Diagnostics (jellybeans defines none; ALE uses these via vim.diagnostic).
  hi DiagnosticError            guifg=#d44141
  hi DiagnosticWarn             guifg=#ffb964
  hi DiagnosticInfo             guifg=#b0d0f0
  hi DiagnosticHint             guifg=#d2ebbe
  hi DiagnosticOk               guifg=#70b950
  hi DiagnosticUnderlineError   gui=undercurl guisp=#d44141
  hi DiagnosticUnderlineWarn    gui=undercurl guisp=#ffb964
  hi DiagnosticUnderlineInfo    gui=undercurl guisp=#b0d0f0
  hi DiagnosticUnderlineHint    gui=undercurl guisp=#d2ebbe
  hi DiagnosticUnderlineOk      gui=undercurl guisp=#70b950

  " Float windows — Neovim default bg (#07080d) is too dark.
  hi NormalFloat                guifg=#e8e8d3 guibg=#1c1c1c
  hi FloatBorder                guifg=#777777 guibg=#1c1c1c

  " Window chrome — Neovim links WinSeparator to Normal; we want gravel.
  hi! link WinSeparator         VertSplit

  " Git gutter signs.
  hi GitGutterAdd               guifg=#70b950
  hi GitGutterChange            guifg=#ffb964
  hi GitGutterDelete            guifg=#d44141
endif
