# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="gallois"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias c='clear'
alias df='df -h'
alias du='du -sh'
alias ls='ls -h --color=auto'
alias g++='g++ -Wall -Wextra -pedantic -std=c++11'
alias reload='. ${HOME}/.zshrc'
alias se='apt-cache search'
alias inst='sudo apt-get install'
alias update='sudo apt-get update'
alias upgrade='sudo apt-get upgrade'
alias lock='gnome-screensaver-command -l'
alias Byobu='byobu -A -D -RR -fa -h 150000 -l -O -U'

xset b off
xset r rate 300 100

export TERMINAL=urxvt

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl:/home/berson_r/build/julia
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib:$HOME/usr/lib:$HOME/.local/lib
export LD_RUN_PATH=$LD_RUN_PATH:$HOME/usr/lib:$HOME/.local/lib

export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
export PATH=$PATH:$HOME/usr/bin # Add ~/usr/bin to path
export PATH=$PATH:$HOME/.local/bin # Add ~/.local/bin to path
export PATH=$PATH:/opt/ghc/7.8.2/bin # Add latest version of GHC
export PATH=/usr/lib/jvm/java-7-oracle/bin:$PATH

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
