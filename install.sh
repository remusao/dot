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

# Pull Submodules
git submodule init
git submodule update --init --recursive

# Create symlinks to config files
for file in emacs \
            gitconfig \
            hgrc \
            i3 \
            i3status.conf \
            config \
            nixpkgs \
            vim \
            vimrc \
            Xdefaults \
            xinitrc \
            zshrc \
            zshrc.pre-oh-my-zsh; do
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
    ln -s $file $path
done

# Install vim plugins
vim +PluginInstall +qall

# Setting up YouCompletMe
cd ${HOME}/.vim/bundle/YouCompleteMe && ./install.sh --clang-completer
