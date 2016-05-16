export TERM='xterm-256color'

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

ZSH=$HOME/.oh-my-zsh
DEFAULT_USER="berson_r"

# Configure zsh theme
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(virtualenv context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status time)
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
ZSH_THEME="powerlevel9k/powerlevel9k"
ZSH_THEME="powerlevel9k/powerlevel9k"
source ~/.oh-my-zsh/oh-my-zsh.sh

# Preferred editor for local and remote sessions
export EDITOR='vim'
export PIP_REQUIRE_VIRTUALENV=true

# Example aliases
alias c='clear'
alias df='df -h'
alias du='du -sh'
alias g++='g++ -Wall -Wextra -pedantic -std=c++11'
alias reload='. ${HOME}/.zshrc'
alias se='apt-cache search'
alias inst='sudo apt-get install'
alias update='sudo apt-get update'
alias upgrade='sudo apt-get upgrade'
alias lock='gnome-screensaver-command -l'
alias Byobu='byobu -A -D -RR -fa -h 150000 -l -O -U'
alias emacs='emacs -nw'

alias g='git status -sb'
alias gh='git hist'
alias gp='git pull'
alias gc='git commit'

alias ltev='. ~/.local/bin/load_cluster_env.sh test && unset CLIQZ_DMZ_GATEWAY'

xset b off
xset r rate 300 100

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib:$HOME/usr/lib:$HOME/.local/lib
export LD_RUN_PATH=$LD_RUN_PATH:$HOME/usr/lib:$HOME/.local/lib
export LIBRARY_PATH=$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$HOME/usr/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$HOME/usr/include:$CPLUS_INCLUDE_PATH

# Extend PATH
export PATH=$PATH:/usr/local/sbin:/usr/bin
export PATH=$HOME/usr/local/bin:$PATH       # Use local first
export PATH=$HOME/.local/bin:$PATH          # ~/.local/bin

# Python Virtualenv
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export VIRTUALENVWRAPPER_VIRTUALENV=`which virtualenv`
export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh

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
