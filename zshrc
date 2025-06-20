#! /usr/bin/zsh

# Load ssh key
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
# export TERM='xterm-256color'
export TERM='rxvt-unicode-256color'
export DEFAULT_USER="remi"
export EDITOR=/home/remi/.local/bin/nvim
export VISUAL=/home/remi/.local/bin/nvim
export TF_PLUGIN_CACHE_DIR=/home/remi/.cache/terraform/

# Cursor speed
xset b off
xset r rate 300 100

# Locales
export LC_COLLATE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8
export LC_MONETARY=en_US.UTF-8
export LC_NUMERIC=en_US.UTF-8
export LC_TIME=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LESSCHARSET=utf-8

# ZSH commands completions
# source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# export ZSH_AUTOSUGGEST_USE_ASYNC='true'
# export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=30'
# export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
# fpath=(~/.zsh/zsh-completions/src $fpath)
export LSCOLORS=gxfxbEaEBxxEhEhBaDaCaD
zstyle -e ':completion:*:default' list-colors 'reply=("${PREFIX:+=(#bi)($PREFIX:t)(?)*==02=01}:${(s.:.)LS_COLORS}")'

# ZSH tab-completion
unsetopt menu_complete   # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu         # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Use caching so that commands like apt and dpkg complete are useable
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path $ZSH_CACHE_DIR

zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ZSH Prompt
POWERLEVEL9K_VCS_SHOW_SUBMODULE_DIRTY=false
POWERLEVEL9K_NODE_VERSION_FOREGROUND='black'
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
# POWERLEVEL9K_MODE="nerdfont-complete"
# POWERLEVEL9K_MODE='awesome-patched'

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir_writable dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(aws status virtualenv node_version time)
source /home/remi/.zsh/powerlevel10k/powerlevel10k.zsh-theme

# Aliases
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias aws=/home/remi/.virtualenvs/neovim3/bin/aws
alias rm='rm -i'
alias Byobu='byobu -A -D -RR -fa -h 150000 -l -O -U'
alias ag='rg --smart-case --pretty'
alias c='clear'
alias df='df -h'
alias du='du -sh'
alias emacs='emacs -nw'
alias g++='g++ -Wall -Wextra -pedantic -std=c++11'
alias inst='sudo apt-get install'
alias lock='i3lock --color 475263'
alias ls="ls --color=auto"
alias reload='. ${HOME}/.zshrc'
alias se='apt-cache search'
alias tree='tree -CAFa -I "CVS|*.*.package|.svn|.git|.hg|node_modules|bower_components" --dirsfirst'
alias update='sudo apt-get update && sudo apt-get upgrade && sudo apt-get dist-upgrade'
alias vim='nvim'
alias aws='~/.virtualenvs/neovim3/bin/aws'

alias runpyenv='eval "$(pyenv init -)"'
alias runnvm='source ~/.nvm/nvm.sh'
alias runasdf='source ~/.asdf/asdf.sh'

# Copy
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

# Pandoc
alias pandock='docker run --rm -v "$(pwd):/data" -u $(id -u):$(id -g) pandoc/extra'

# Globals
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib:$HOME/usr/lib:$HOME/.local/lib
export LD_RUN_PATH=$LD_RUN_PATH:$HOME/usr/lib:$HOME/.local/lib
export LIBRARY_PATH=$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$HOME/usr/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$HOME/usr/include:$CPLUS_INCLUDE_PATH

# Extend PATH
export PATH=$PATH:/usr/local/sbin:/usr/bin
export PATH=$HOME/usr/local/bin:$PATH                   # Use local first
export PATH=$HOME/.local/bin:$PATH                      # ~/.local/bin
export PATH=$HOME/.local/spark-1.6.1/bin:$PATH          # ~/.local/spark-1.6.1/
export PATH=$HOME/.local/nodejs/bin:$PATH               # nodejs packages (npm)
export PATH=$HOME/.cargo/bin:$PATH                      # Rust
export PATH=$HOME/dev/repositories/public/Nim/bin:$PATH # Nim
export PATH=$HOME/.gem/ruby/2.5.0/bin:$PATH             # Ruby gems
export PATH=$HOME/dev/repositories/public/julia/usr/bin:$PATH # Julialang
export PATH=$HOME/.pyenv/bin:$PATH                      # Add pyenv to PATH
export PATH=$HOME/.pyenv/versions/${PYTHON_VERSION}/bin:$PATH   # Add python to PATH
export PATH=$HOME/.jsvu:$PATH                           # Javascript engines
export PATH=$HOME/.poetry/bin:$PATH                     # Poetry (Python)
export PATH=$PATH:/home/remi/.go/bin
export PATH=$PATH:/home/remi/go/bin
export PATH=$PATH:/opt/ghc/bin/ # Haskell
export PATH=$HOME/.ghcup/bin/:$PATH # Haskell (ghcup)
export PATH=$HOME/.cabal/bin/:$PATH # Haskell (Cabal)

export GOPATH=/home/remi/go

# Rust cargo
# export RUSTC_WRAPPER="/home/remi/.cargo/bin/sccache"

export GEM_HOME=$HOME/.gem/

# Init Android Studio
export ANDROID_HOME=$HOME/.sandboxes/android-studio/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Init pyenv
export PYENV_ROOT="$HOME/.pyenv"

# Python Virtualenv
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export VIRTUALENVWRAPPER_VIRTUALENV=`which virtualenv`
export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME
source /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh

export PIP_REQUIRE_VIRTUALENV=true

# History management
HISTFILE=$HOME/.zsh_history      # enable history saving on shell exit
HISTSIZE=1000000                   # lines of history to maintain memory
SAVEHIST=1000000                   # lines of history to maintain in history file.

setopt EXTENDED_HISTORY         # save timestamp and runtime information
setopt APPEND_HISTORY           # append rather than overwrite history file.
setopt SHARE_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

export NVM_DIR="$HOME/.nvm"
export PATH=${HOME}/.nvm/versions/node/v${NODEJS}/bin/:${PATH}

# Set title
set-window-title() {
  # /Users/clessg/projects/dotfiles -> ~/p/dotfiles
  window_title="\e]0;${${PWD/#"$HOME"/~}/projects/p}\a"
  echo -ne "$window_title"
}

PR_TITLEBAR=''
set-window-title
add-zsh-hook precmd set-window-title

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

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Customize fzf
# export FZF_DEFAULT_COMMAND='rg --files --smart-case --glob "!.git/*"'

# Run vim with ctrl-p when ctrl-p is pressed in zsh
ctrlp() {
  </dev/tty vim -c CtrlP
}
zle -N ctrlp

bindkey "^p" ctrlp

# Run vim with Fzf when ctrl-f is pressed in zsh
nvim_fzf() {
  </dev/tty vim -c Rg
}
zle -N nvim_fzf

bindkey "^f" nvim_fzf

zmodload zsh/zpty

export PATH="$HOME/.poetry/bin:$PATH"

# ASDF (versions manager)
# . $HOME/.asdf/asdf.sh

# Completions
# append completions to fpath
# fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

######################
# Semgrep single PRs #
######################
# spr() {
# 	last="${@:$#}" # last parameter
# 	other="${*%${!#}}" # all parameters except the last
# 	BASE_COMMIT=${BASE_COMMIT:-origin/master}
# 	NEW_HEAD="$last"
# 	TEMPDIR="$(mktemp -d)"
# 	pushd "$PWD"
# 	git worktree add $TEMPDIR $last
# 	cd $TEMPDIR
# 	FILES="$(git --no-pager diff --name-only $last $(git merge-base $last $BASE_COMMIT) | xargs ls -d 2>/dev/null)"
# 	semgrep $other $FILES
# 	popd
# 	rm -rf $TEMPDIR
# }

# [ -f "/home/remi/.ghcup/env" ] && . "/home/remi/.ghcup/env" # ghcup-env
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
