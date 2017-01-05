export TERM='xterm-256color'

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

ZSH=$HOME/.oh-my-zsh
DEFAULT_USER="remi"

# Configure zsh theme
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(background_jobs status vi_mode virtualenv node_version time)
POWERLEVEL9K_NODE_VERSION_FOREGROUND='black'
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
ZSH_THEME="powerlevel9k/powerlevel9k"

# Preferred editor for local and remote sessions
export EDITOR='vim'
export PIP_REQUIRE_VIRTUALENV=true

# Example aliases
alias c='clear'
alias df='df -h'
alias du='du -sh'
alias g++='g++ -Wall -Wextra -pedantic -std=c++11'
alias reload='. ${HOME}/.zshrc'
alias se='sudo apt-cache search'
alias inst='sudo apt-get install'
alias update='sudo apt-get update'
alias upgrade='sudo apt-get upgrade'
alias lock='i3lock --color 475263'
alias Byobu='byobu -A -D -RR -fa -h 150000 -l -O -U'
alias emacs='emacs -nw'
alias vim='nvim'

alias g='git status -sb'
alias gh='git hist'
alias gp='git pull'
alias gc='git commit'

alias ltev='. ~/.local/bin/load_cluster_env.sh test && unset CLIQZ_DMZ_GATEWAY'
alias lpev='. ~/.local/bin/load_cluster_env.sh primary && unset CLIQZ_DMZ_GATEWAY'

xset b off
xset r rate 300 100

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib:$HOME/usr/lib:$HOME/.local/lib
export LD_RUN_PATH=$LD_RUN_PATH:$HOME/usr/lib:$HOME/.local/lib
export LIBRARY_PATH=$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$HOME/usr/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$HOME/usr/include:$CPLUS_INCLUDE_PATH

# Extend PATH
export PATH=$PATH:/usr/local/sbin:/usr/bin
export PATH=$HOME/usr/local/bin:$PATH           # Use local first
export PATH=$HOME/.local/bin:$PATH              # ~/.local/bin
export PATH=$HOME/.local/spark-1.6.1/bin:$PATH  # ~/.local/spark-1.6.1/
export PATH=$HOME/.local/nodejs/bin:$PATH       # nodejs packages (npm)

# Python Virtualenv
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export VIRTUALENVWRAPPER_VIRTUALENV=`which virtualenv`
export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME

# Investigate tmux plugin
# tmuxinator
plugins=(gitfast vagrant virtualenvwrapper npm pip python supervisor systemd command-not-found common-aliases docker)
source ~/.oh-my-zsh/oh-my-zsh.sh

# Extra configuration
if [ -e "$HOME/.zshlocal" ];
then
    source $HOME/.zshlocal
fi

# History management
HISTFILE=$HOME/.zsh_history    # enable history saving on shell exit
setopt APPEND_HISTORY          # append rather than overwrite history file.
HISTSIZE=100000                # lines of history to maintain memory
SAVEHIST=100000                # lines of history to maintain in history file.
setopt HIST_EXPIRE_DUPS_FIRST  # allow dups, but expire old ones when I hit HISTSIZE
setopt EXTENDED_HISTORY        # save timestamp and runtime information

[ -z "$NVM_DIR" ] && export NVM_DIR="$HOME/.nvm"
source /usr/share/nvm/nvm.sh
source /usr/share/nvm/bash_completion
source /usr/share/nvm/install-nvm-exec
