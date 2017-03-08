#! /usr/bin/env sh

backupfile() {
    backup=`pwd`/backup
    if [ ! -e $backup ];
    then
        echo Creating backup dir: $backup
        mkdir $backup
    fi
    tosave=$1
    echo Backing up $tosave into $backup
    mv $tosave $backup
}

# Install package:
# zsh-syntax-highlighting


# Pull Submodules
git submodule init
git submodule update --init --recursive

# Install custom fonts
echo "Install fonts"
if test ! -d /tmp/fonts ; then
    git clone https://github.com/powerline/fonts.git /tmp/fonts
fi
/tmp/fonts/install.sh

ZSH_HOME='/home/remi/.zsh/'
mkdir -v ${ZSH_HOME}

# Install zsh completion
if test ! -d ${ZSH_HOME}/zsh-completions ; then
    git clone git://github.com/zsh-users/zsh-completions ${ZSH_HOME}/zsh-completions
fi

# Install zsh auto-suggest
if test ! -d ${ZSH_HOME}/zsh-autosuggestions ; then
    git clone git://github.com/zsh-users/zsh-autosuggestions ${ZSH_HOME}/zsh-autosuggestions
fi

# Install zsh prompt
if test ! -d ${ZSH_HOME}/powerlevel9k ; then
    git clone https://github.com/bhilburn/powerlevel9k.git ${ZSH_HOME}/powerlevel9k
fi

# Create symlinks to config files
for file in Xresources \
            config \
            emacs \
            gitconfig \
            hgrc \
            i3 \
            i3status.conf \
            nixpkgs \
            vim \
            vimrc \
            xinitrc \
            zshrc ; do
    # Add $HOME prefix and '.' in front of file name
    path=${HOME}/.${file}
    file=`pwd`/${file}
    # Check if file already exists
    if [ -e $path ];
    then
        if [ -L $path ];
        then
            echo "$path symlink exists (action: delete)"
            rm $path
        else
            echo "$path already exists (action: save)"
            backupfile $path
        fi
    fi
    echo "Creating symlink $file -> $path"
    ln -sf $file $path
done

# Install vim plugins
# vim +NeoBundleInstall +qall
