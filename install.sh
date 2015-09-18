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

git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

# Create symlinks to config files
for file in Xdefaults \
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
            zlogin \
            zlogout \
            zpreztorc \
            zprofile \
            zshenv \
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
    ln -s $file $path
done

# Install vim plugins
vim +NeoBundleInstall +qall
