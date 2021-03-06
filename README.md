set-up-configs
==============

Bash-Script to manage "dotfiles" with git and symlinks. Has add/unlink/merge support.

Usage: set-up-configs.sh [OPTION...] [NAME] [FILES]

```
 -a <name> <file1> [<file2>...]   add config files to a program
 -f                               force overwriting conflicting files
 -h                               print this help list
 -o                               only pull/clone if $GIT_HOST is up
 -q                               quiet: only output errors, do not overwrite files
 -u <name>                        unlink all config files of a program
 -v                               increase verbosity of output
```

Initial setup:
 - Create a git repository somewhere (e.g., on github)
 - Either create $HOME/.set-up-configs file to set the following variables or
   fork this repository and edit the set-up-configs.sh file directly:
   - Set variable $REPOSITORY, to reflect the location of your git repository
   - Set variable $DOT, the local clone of your git repository
     (path relative to $HOME)


 - Add vim to git-repository and create symlinks in place of the original files:
```
     $ set-up-configs.sh -a vim .vimrc .vim/colors/summerfruit256.vim
```
   - Now go to your $DOT directory and commit the files
   - On other machines run set-up-configs.sh without arguments to:
     update and link config files from repository

 - Add all files in a subdirectory, for example "awesome" windowmanager themes:
```
     $ find .awesome/themes -type f -print0 | xargs -0 set-up-configs.sh -a awesome
```

 - Remove vim from repository and restore regular config files:
```
   $ set-up-configs.sh -u vim
```
   - The config files will remain in $REPOSITORY
   - The original config file locations (symlinks) are replaced with copies from $REPOSITORY.

 - Replace all config files with symlinks to git repository on new shell:
```
   $ set-up-configs.sh -f
```

