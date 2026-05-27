#! /usr/bin/zsh

# Load ssh key (must be before P10k instant prompt — keychain produces console output)
eval `keychain --agents 'ssh,gpg' --eval id_ed25519 id_rsa_perso id_rsa_cliqz`
export GPG_TTY=$(tty)

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.dot/lock.sh

# Options
export DEFAULT_USER="remi"
export EDITOR="$HOME/.local/bin/nvim"
export VISUAL="$HOME/.local/bin/nvim"
export PAGER='less'
export LESS='-RF'
export LESSHISTFILE=-
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export TF_PLUGIN_CACHE_DIR="$HOME/.cache/terraform"

# X11 cursor tweaks (only run once per X session — guarded by sentinel env var)
if [[ -n "$DISPLAY" && -z "$_XSET_DONE" ]] && command -v xset >/dev/null 2>&1; then
  xset b off
  xset r rate 300 100
  export _XSET_DONE=1
fi
setopt NO_BEEP
setopt AUTO_PUSHD           # cd pushes old dir onto stack
setopt PUSHD_IGNORE_DUPS    # dedup dir stack
setopt INTERACTIVE_COMMENTS # allow # comments at the prompt
setopt NO_NOMATCH           # pass unmatched globs literally instead of erroring

# Locale (LC_ALL overrides any individual LC_* setting)
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LESSCHARSET=utf-8

# Editing keymap (zsh otherwise picks vi mode because EDITOR=*vi*)
bindkey -e
WORDCHARS=${WORDCHARS//[\/]}   # treat / as word boundary (Ctrl-W stops at path components)

# Completions: dynamic prefix highlighting in lists
zstyle -e ':completion:*:default' list-colors 'reply=("${PREFIX:+=(#bi)($PREFIX:t)(?)*==02=01}:${(s.:.)LS_COLORS}")'

# ZSH tab-completion
unsetopt menu_complete   # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu         # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Cache expensive completions (apt, dpkg, etc.)
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"

# ZSH Prompt
POWERLEVEL9K_VCS_SHOW_SUBMODULE_DIRTY=false
POWERLEVEL9K_NODE_VERSION_FOREGROUND='black'
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir_writable dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status virtualenv node_version command_execution_time background_jobs time)
POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS=0.1
source "$HOME/.zsh/powerlevel10k/powerlevel10k.zsh-theme"

# Aliases
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias rm='rm -i'
alias Byobu='byobu -A -D -RR -fa -h 150000 -l -O -U'
alias ag='rg --smart-case --pretty'
alias c='clear'
alias df='df -h'
alias du='du -sh'
alias emacs='emacs -nw'
alias g++='g++ -Wall -Wextra -pedantic -std=c++20'
alias inst='sudo apt install'
alias lock='i3lock --color 475263'
alias ls="ls --color=auto"
alias l='eza --group-directories-first --git'
alias la='eza -la --group-directories-first --git --time-style=long-iso'
alias lt='eza --tree --git-ignore --level=2'
alias reload='exec zsh'
alias se='apt search'
alias tree='tree -CAFa -I "CVS|*.*.package|.svn|.git|.hg|node_modules|bower_components" --dirsfirst'
alias update='sudo apt update && sudo apt full-upgrade'
alias vim='nvim'
alias runpyenv='eval "$(pyenv init -)"'
alias runnvm='source ~/.nvm/nvm.sh'

# Clipboard (display-server-aware)
if [[ "$XDG_SESSION_TYPE" = "wayland" ]] && command -v wl-copy >/dev/null 2>&1; then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
else
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
fi

# Pandoc
alias pandock='docker run --rm -v "$(pwd):/data" -u $(id -u):$(id -g) pandoc/extra'

# Custom lib/include paths (no leading colon → no CWD in search path).
# /usr/local/lib and /usr/lib already in /etc/ld.so.conf; don't re-add.
export LD_LIBRARY_PATH="$HOME/usr/lib:$HOME/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export C_INCLUDE_PATH="$HOME/usr/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
export CPLUS_INCLUDE_PATH="$HOME/usr/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"

# ── PATH ────────────────────────────────────────────────────
# Listed in priority order. typeset -U deduplicates.
path=(
  $HOME/.opencode/bin
  $HOME/.bun/bin
  $HOME/.nvm/versions/node/v${NODEJS_VERSION}/bin
  $HOME/.pyenv/versions/${PYTHON_VERSION}/bin
  $HOME/.pyenv/bin
  $HOME/.cargo/bin
  $HOME/.local/nodejs/bin
  $HOME/.local/bin
  $HOME/usr/local/bin
  $path
  /usr/local/sbin
  /usr/bin
  $HOME/.go/bin
  $HOME/go/bin
)
typeset -U path PATH

export GOPATH="$HOME/go"

export GEM_HOME="$HOME/.gem"

# Init pyenv
export PYENV_ROOT="$HOME/.pyenv"

# Python Virtualenv
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
export VIRTUALENVWRAPPER_VIRTUALENV=/usr/bin/virtualenv
export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME
[[ -f /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh ]] && \
  source /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh

export PIP_REQUIRE_VIRTUALENV=true

# History management
HISTFILE=$HOME/.zsh_history      # enable history saving on shell exit
HISTSIZE=1000000                   # lines of history to maintain memory
SAVEHIST=1000000                   # lines of history to maintain in history file.

setopt EXTENDED_HISTORY         # save timestamp and runtime information
setopt SHARE_HISTORY            # implies INC_APPEND_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE        # prefix with space to omit from history
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY              # show history expansions before executing

export NVM_DIR="$HOME/.nvm"

# Set terminal title (~/dev/repositories/project → ~/d/r/project)
autoload -Uz add-zsh-hook
set-window-title() {
  local title="${${PWD/#"$HOME"/~}/projects/p}"
  print -Pn "\e]0;${title}\a"
}
set-window-title
add-zsh-hook precmd set-window-title

# Reset cursor to steady block after each command (urxvt ignores cursorBlink on nvim exit)
if [[ $TERM == *rxvt* || $COLORTERM == *rxvt* ]]; then
  reset-cursor() { printf '\e[2 q' }
  add-zsh-hook precmd reset-cursor
fi

# Syntax coloring
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern root)
ZSH_HIGHLIGHT_STYLES[default]='none'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[alias]='fg=blue'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=none'
ZSH_HIGHLIGHT_STYLES[function]='fg=blue'
ZSH_HIGHLIGHT_STYLES[command]='fg=blue'
ZSH_HIGHLIGHT_STYLES[precommand]='none'
ZSH_HIGHLIGHT_STYLES[commandseparator]='none'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=blue'
ZSH_HIGHLIGHT_STYLES[path]='none'
ZSH_HIGHLIGHT_STYLES[path_prefix]='none'
ZSH_HIGHLIGHT_STYLES[path_approx]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=green'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=green'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=red'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[assign]='none'

# start typing + [Up-Arrow] - fuzzy find history forward
autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search
bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search

# start typing + [Down-Arrow] - fuzzy find history backward
autoload -U down-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

bindkey ' ' magic-space # [Space] - do history expansion

# Extra configuration
if [ -e "$HOME/.zshlocal" ];
then
    source $HOME/.zshlocal
fi

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --bind ctrl-z:toggle+down'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --level=2 {}'"
export FZF_CTRL_R_OPTS="--layout=default"

# fzf shell integration (cached; invalidates on fzf version change)
() {
  local ver=${${(z)$(fzf --version)}[1]}
  local fzf_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf-${ver}.zsh"
  [[ -r $fzf_cache ]] || { mkdir -p ${fzf_cache:h} && fzf --zsh > $fzf_cache }
  source $fzf_cache
}

# zoxide (smart cd)
eval "$(zoxide init zsh)"

# Run vim with ctrl-p when ctrl-p is pressed in zsh
ctrlp() {
  </dev/tty vim -c ProjectFiles
}
zle -N ctrlp

bindkey "^p" ctrlp

# Run vim with Fzf when ctrl-f is pressed in zsh
nvim_fzf() {
  </dev/tty vim -c Rg
}
zle -N nvim_fzf

bindkey "^f" nvim_fzf

# User-installed zsh completions (alacritty, etc.)
fpath=(~/.zsh_functions $fpath)

# Completions (full rebuild once per day, fast load otherwise)
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Compile zcompdump to bytecode for faster subsequent loads (background, disowned)
{
  [[ -s ~/.zcompdump && (! -s ~/.zcompdump.zwc || ~/.zcompdump -nt ~/.zcompdump.zwc) ]] &&
    zcompile ~/.zcompdump
} &!

# bun (only if installed)
if [[ -d "$HOME/.bun" ]]; then
  export BUN_INSTALL="$HOME/.bun"
  [[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
fi
true   # ensure non-failing exit at end of rc
