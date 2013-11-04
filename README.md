set-up-configs
==============

Bash-Script to manage "dotfiles" with git and symlinks. Has add/unlink/merge support.

Usage: set-up-configs.sh [OPTION...] [NAME] [FILES]

  -a <name> <file1> [<file2>...]   add config files to a program
  -f                               force overwriting conflicting files
  -h                               print this help list
  -q                               quiet: only output errors, don't overwrite files
  -u <name>                        unlink all config files of a program
  -v                               increase verbosity of output

Initial setup:
 - Create a git repository somewhere (e.g., on github)
 - Fork and edit the set-up-configs.sh file:
   - Set variable $REPOSITORY, to reflect the location of your git repository
     (path relative to $HOME)
   - Set variable $DOT, the local clone of your git repository

 - Add vim to git-repository and create symlinks in place of the original files:
     $ set-up-configs.sh -a vim .vimrc .vim/colors/summerfruit256.vim
   - Now go to your \$DOT directory and commit the files
   - On other machines run set-up-configs.sh without arguments to:
     update and link config files from repository

 - Remove vim from repository and restore regular config files:
   $ set-up-configs.sh -u vim
   - The config files will remain in \$REPOSITORY
   - The original config file locations (symlinks) are replaced with copies from \$REPOSITORY.

 - Replace all config files with symlinks to git repository on new shell:
   $ set-up-configs.sh -f
