""" Syntax Coloration
syntax enable
syntax on
set t_Co=256
let g:enable_bold_font = 1
set background=dark
colorscheme jellybeans
let g:jellybeans_use_lowcolor_black = 0

" Neovim 0.10+ compat: hi clear now resets to Neovim's new default
" colorscheme instead of Vim's legacy defaults (PR #26334). Re-establish
" standard TreeSitter-to-Vim links for groups jellybeans doesn't define.
if has('nvim-0.10')
  " TreeSitter groups → jellybeans base groups
  hi! link @variable          Identifier
  hi! link @constant          Constant
  hi! link @constant.builtin  Special
  hi! link @module            Identifier
  hi! link @string            String
  hi! link @string.escape     Special
  hi! link @character         Constant
  hi! link @number            Constant
  hi! link @boolean           Constant
  hi! link @function          Function
  hi! link @function.builtin  Special
  hi! link @function.call     Function
  hi! link @constructor       Special
  hi! link @operator          Structure
  hi! link @keyword           Statement
  hi! link @type              Type
  hi! link @type.builtin      Type
  hi! link @attribute         PreProc
  hi! link @comment           Comment
  hi! link @punctuation       Delimiter
  hi! link @tag               Statement
  hi! link @tag.delimiter     Delimiter
  hi! link @tag.attribute     Identifier
  hi! link @markup.heading    Title
  hi! link @markup.link.url   Underlined

  " Old flat names (Neovim 0.10 / older parsers)
  hi! link @field             Identifier
  hi! link @property          Identifier
  hi! link @parameter         Identifier
  hi! link @method            Function
  hi! link @method.call       Function
  hi! link @conditional       Statement
  hi! link @repeat            Statement
  hi! link @exception         Statement
  hi! link @include           PreProc
  hi! link @namespace         Identifier
  hi! link @float             Constant
  hi! link @string.regex      String
  hi! link @text.uri          Underlined

  " Semantic groups new in 0.10
  hi! link Added              String
  hi! link Changed            Statement
  hi! link Removed            Constant

  " Float window defaults changed in 0.10
  hi! link NormalFloat        Pmenu
  hi! link FloatBorder        VertSplit
endif

" lua << EOF
"   require("themer").setup({
" 	  colorscheme = "jellybeans",
"     term_colors = true,
" 	  styles = {
"       variable = { fg = "#c6b6ee" },
" 	  },
" 	})
" EOF
