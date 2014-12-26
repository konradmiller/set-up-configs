#!/bin/bash

# This script is will set will manage your config files
# in a git repository.
#
# Set $DOT to a local directory relative to $HOME
# 	this is where the git-repository will be checked out
# Set $REPOSITORY to your dotfiles git repository

# Quiet flag: -q
# When this script is run with the -q argument, it will
# - Clone/pull your git repository and
# - update config files unintrusively
# No existing config files will be overwritten.
# Run ./set-up-configs.sh -q from your .bash_profile!

# Force flag: -f
# When -f is given, existing config files are overwritten! The script will:
# - Clone/pull your git repository
# - Replace all config files with symlinks to git repository
# Only use it to set up your config files on a new shell

# Add flag: -a
# Add a new program "name" with the following files to git repo
# Copy original config files to git and replace them with symlinks
# Also adds files to an existing program.
# 	set-up-configs.sh -a "name" <file1> [<file2> ...]
# Use -a to manage config files of a new program

# Unlink flag: -u
# This is the opposite of the add flag.
# Remove symlinks and copy files from repository to their original positions
#	set-up-configs.sh -u "name"

# Online check: -o
# Only update repository if the git server is returning pings

# I didn't want to deal with the paths too much, so only run this from $HOME kids!
# (And don't try to add anyting below your $HOME into the git)

[[ "$PWD" != "$HOME" ]] && echo "Always call $0 from $HOME" && exit



#############################################################
# The location of the git repository containing the config files
# Modify those variables to match your setup

# You can either set the config values...
if [[ ! -r "$HOME/.set-up-configs" ]]
then
	# ... right here in this script ...
	DOT=".dotfiles"   # Local directory where to clone the config files
	GIT_HOST=""       # Hostname - only used for online-check (-o)
	REPOSITORY=""     # Full name, hostname and path to git repository
	DIFF="vimdiff"    # Program to merge conflicts
else
	# ... or in a separate config file located at ~/.set-up-configs
	source "$HOME/.set-up-configs"
fi



#############################################################
# don't set another language, it may break eventual output parsing

LANG=C



#############################################################
# echo functions
GREEN='\033[01;32m'
RED='\033[01;31m'
WHITE='\033[00m'
YELLOW='\033[0;33m'

# echo white, green or red (unless -q was given, or if -v is given with -q)
function out()   { [[ $VERBOSE -eq 1 || $QUIET -ne 1 ]] && echo -e "$@"; }
function ok()    { [[ $VERBOSE -eq 1 || $QUIET -ne 1 ]] && echo -e "${GREEN}$@${WHITE}"; }
function fail()  { [[ $VERBOSE -eq 1 || $QUIET -ne 1 ]] && echo -e "${RED}$@${WHITE}" >&2; }

# only echo if -v is given
function debug() { [[ $VERBOSE -eq 1 ]] && echo -e "+++ ${YELLOW}$@${WHITE}"; }



#############################################################
# commandline parsing

ADD=0
FORCE=0
HELP=0
ONLINE_ONLY=0
QUIET=0
UNLINK=0
VERBOSE=0

while getopts ":fhoqva:u:" OPTION
do
	case $OPTION in
		f) FORCE=1               ;;
		h) HELP=1                ;;
		o) ONLINE_ONLY=1         ;;
		q) QUIET=1               ;;
		v) VERBOSE=1             ;;

		a) ADD=1;   NAME=$OPTARG ;;
		u) UNLINK=1 NAME=$OPTARG ;;

		\?)
			fail "Unknown option: -$OPTARG"
			HELP=1
			;;

		:)
			fail "Option -$OPTARG requires an argument"
			HELP=1
			;;
	esac
done


# get rid of commandline options
# (the rest of the arguments are file arguments, if present)
shift $((OPTIND-1))

# export ATN and exit
# ATN is meant to transport information despite "quiet background operation"
# --> ignore output but warn if SETUPCONFIGS_ATN is set and config file
#     repository requires attention
# 1 == repository update/pull failed
# 2 == configuration incomplete
# 3 == contradicting flags
function die()
{
	case "$2" in
		0)
			debug "all good, no errors"
			export SETUPCONFIGS_ATN=""
			exit 0
			;;
		1)
			fail "\tfailed"
			out "Error:\n$1"
			export SETUPCONFIGS_ATN="dotfile clone/pull failed"
			exit 1
			;;
		2)
			fail "Error:\n$1"
			export SETUPCONFIGS_ATN="configuration incomplete"
			exit 2
			;;
		3)
			fail "Error:\n$1"
			export SETUPCONFIGS_ATN="contradicting flags given"
			exit 3
			;;
	esac

}


function environment_check()
{
	if [[ -z "$DOT" ]] || [[ -z "$REPOSITORY" ]]
	then
		die "You need to export at least \$DOT and \$REPOSITORY" 2
	fi

	# $GIT_HOST is only required if -o is requested and used as the ping target
	# The idea ist, that you can also use e.g., "8.8.8.8" if your
	# $GIT_HOST does not send ICMP replies
	# $REPOSITORY generally also contains the actual $GIT_HOST
	if [[ $ONLINE_ONLY -eq 1 ]] && [[ -z "$GIT_HOST" ]]
	then
		die "You need to export \$GIT_HOST if you pass -o" 2
	fi

	# You need to decide if you want to add or unlink ;-)
	if [[ $UNLINK -eq 1 ]] && [[ $ADD -eq 1 ]]
	then
		die "error: you cannot add files (-a) and unlink files (-u) at the same time" 3
	fi
}


# Waiting for git to fail when we're not online is annoying
# ping returns quicker when a short timeout (e.g., .5s) is given
# --> Skip git pull/git clone if ping doesn't return
function online_check()
{
	ping -q -c 3 -o -i .1 -W .5 $GIT_HOST &>/dev/null
	[[ $? -eq 0 ]] && ONLINE=1 || ONLINE=0
}


function update_repository()
{
	if [[ "$ONLINE_ONLY" -eq 1 ]]
	then
		online_check
		if [[ $ONLINE -ne 1 ]]
		then
			fail "Git host is not reachable - skipping clone/pull of dotfiles"
			return
		else
			debug "Git host is reachable"
		fi
	fi

	if [[ -d "$DOT" ]]
	then
		# update repository
		out -n "+ Checking repository for updates... "
		RES=$(cd "$DOT" && git pull 2>&1)
	else
		# clone repository
		out -n "+ Cloning dotfiles repository... "
		RES=$(cd "$HOME" && git clone $REPOSITORY .dotfiles 2>&1)
	fi
	# first get return value of git command, then echo
	RET=$?
	[[ "$RET" -eq 0 ]] && (ok "\tdone") || (die "$RES" 1)
}

#############################################################

# check if all config files of a program are up-to-date
# only print message on conflicts if -q is given
# overwrite local files if -f is given
# ask what to do on conflicts without arguments
function setup_program()
{
	PROGRAM=$1
	debug "Processing program $PROGRAM"

	# traverse all files
	while IFS= read -r -u3 -d $'\0' FILE; do

		# get rid of ./ prefix
		FILE=${FILE:2}

		debug "processing config file: $FILE "
		SOURCE=$HOME/$FILE
		TARGET=$HOME/$DOT/$PROGRAM/$FILE

		# Link is correct, we are done with this file :)
		[[ -L $SOURCE ]] && [[ $TARGET == "$(readlink $SOURCE)" ]] && continue

		# File exists and we are in quiet mode -> Ignore
		[[ -a $SOURCE ]] && [[ $QUIET -eq 1 ]] && continue

		# File does not exist, create it -> done :)
		if [[ ! -a "$SOURCE" ]]
		then
			# ...if it doesnt exist, we create it and are done.
			out -n "+ Config file $FILE is new, creating link."
			mkdir -p "$(dirname $SOURCE)"
			RES=$(ln -s "$TARGET" "$SOURCE" 2>&1)
			RET=$?
			[[ "$RET" -eq 0 ]] && (ok "\tdone") || (fail "\tfailed"; out "$RES"; exit 2)
			continue
		fi

		[[ ! -f "$SOURCE" ]] && [[ ! -L "$SOURCE" ]] \
			&& fail "$SOURCE is neither a file nor a symlink -> ignoring" \
			&& continue

		# There is a regular file or incorrect symlink there
		if [[ $FORCE -eq 1 ]]
		then
			out "Overwriting $SOURCE"
			rm "$SOURCE"
			ln -s "$TARGET" "$SOURCE"
			continue
		fi

		# we already filtered
		#    - correct symlinks and
		#    - $QUIET mode
		# --> prompt for the last two cases
		if [[ -L "$SOURCE" ]]
		then
			read -p "Config file $SOURCE is a symlink pointing to $(readlink $SOURCE). Overwrite? (y|n) " -n 1 -r
			echo
			if [[ "$REPLY" =~ ^[Yy]$ ]]
			then
				rm "$SOURCE"
				ln -s "$TARGET" "$SOURCE"
			fi
			continue
		fi

		if [[ -f "$SOURCE" ]]
		then
			PROMPT_DONE=0
			while [[ $PROMPT_DONE -eq 0 ]]
			do
				echo -n "Config file $SOURCE already exists. Options: "
				read -p "(d)iff, overwrite (l)ocal, overwrite (r)epo, (i)gnore " -n 1 -r
				echo
				case "$REPLY" in
					d|D)
						$DIFF "$SOURCE" "$TARGET"
						;;
					l|L)
						# overwrite local file with file in repository
						rm "$SOURCE"
						ln -s "$TARGET" "$SOURCE"
						PROMPT_DONE=1
						;;
					r|R)
						# overwrite repository file with local one
						rm "$TARGET"
						mv "$SOURCE" "$TARGET"
						ln -s "$TARGET" "$SOURCE"
						PROMPT_DONE=1
						;;
					*)
						out "Ignoring $SOURCE for now..."
						PROMPT_DONE=1
						;;
				esac
			done
			continue
		fi

		fail "$SOURCE fell all the way through, something is probably wrong!"

	done 3< <(cd $DOT/$PROGRAM && find . -type f -print0)
}


# we get here, if script is called without -a or -u
# first we check out/update the git repo
# and then call the setup_program function above with every directory
function setup()
{
	update_repository
	# traverse all directories in repository, except .git
	while IFS= read -r -u3 -d $'\0' PROGRAM; do

		# get rid of the $DOT prefix
		PROGRAM=${PROGRAM:$[1+${#DOT}]}

		setup_program $PROGRAM

	done 3< <(find "$DOT" -mindepth 1 -maxdepth 1 \
			-path "$DOT/.git" -prune -o \
			-type d -print0)
}



#############################################################
# we get here, if the user wants to add files to a (new) program
# 	set-up-configs.sh -a "name" <file1> [<file2> ...]

function add()
{
	# check out repository if it has never been pulled at all
	[[ ! -d $DOT/.git ]] && update_repository

	if [[ -d "$DOT/$NAME" ]]
	then
		echo "+ adding config files to program $NAME"
	elif [[ -a "$DOT/$NAME" ]]
	then
		fail "+ program-name $NAME exists, but is not a directory"
	else
		echo "+ storing config files for new program $NAME"
		mkdir -p "$DOT/$NAME"
	fi

	while [[ ! -z "$1" ]]
	do
		FILE="$1"
		debug "Processing $FILE"

		# is $FILE given as a relative path?
		if [[ "${FILE:0:1}" == "/" ]]
		then
			fail "Please pass only relative paths. I will ignore $FILE."
			shift && continue
		fi

		# is the source an actual file?
		if [[ ! -f "$FILE" ]]
		then
			fail "Hey, $FILE is not a regular file. I will ignore it!"
			shift && continue
		fi

		# create path in git-repo (unless the file is directly in $HOME)
		REL_DIR=$(dirname "$FILE")
		REPO_DIR="$DOT/$NAME"
		if [[ "$REL_DIR" != "." ]]
		then
			REPO_DIR="$DOT/$NAME/$REL_DIR"
			mkdir -p "$REPO_DIR"
		fi
		FILENAME=$(basename $FILE)
		REPO_FILE="$REPO_DIR/$FILENAME"

		# does this file-name already live in $NAME?
		if [[ -a "$REPO_FILE" ]]
		then
			fail "$FILE already exists in the git repository. I will ignore it!"
			fail "If you want to overwrite the file in repo do:"
			fail "mv $FILE $REPO_FILE && ln -s $REPO_FILE $FILE"
			shift && continue
		fi

		# add file to config directory...
		mv "$FILE" "$REPO_FILE"

		# ...and symlink it to original location
		ln -s "$HOME/$REPO_FILE" "$FILE"

		# add file to git repo
		(cd "$DOT" && git add "$NAME/$REL_DIR/$FILENAME")

		# shift to next file
		shift
	done

	echo "Remember committing the new files in $DOT!"
}



#############################################################
# we get here, if the user wants to remove symlinks and
# copy files from repository to their proper positions
#	set-up-configs.sh -u "name"

function unlink()
{
	[[ ! -d $DOT/.git ]] && fail "Git-repository does not exist" && exit 1

	PROGRAM=$NAME
	debug "Unlinking program $PROGRAM"

	# traverse all files
	while IFS= read -r -u3 -d $'\0' FILE; do

		# get rid of ./ prefix
		FILE=${FILE:2}

		debug "unlinking config file: $FILE "
		SOURCE=$HOME/$FILE
		TARGET=$HOME/$DOT/$PROGRAM/$FILE

		[[ ! -L $SOURCE ]] && fail "$SOURCE is not a symlink" && continue
		[[ $TARGET != "$(readlink $SOURCE)" ]] && fail "$SOURCE does not link to $TARGET" && continue

		# everything is ok, config file is a proper symlink to repo
		out -n "Replacing symlink $SOURCE with original in repo"
		RES=$(cp --remove-destination "$TARGET" "$SOURCE" 2>&1)
		RET=$?
		[[ "$RET" -eq 0 ]] && (ok "\tdone") || (fail "\tfailed"; out "$RES"; exit 2)

	done 3< <(cd $DOT/$PROGRAM && find . -type f -print0)
}



#############################################################
# decide where to go with the given options

# Help superseeds everything
if [[ $HELP -eq 1 ]]
then
	echo "Usage: $0 [OPTION...] [NAME] [FILES]"
	echo
	echo "  -a <name> <file1> [<file2>...]   add config files to a program"
	echo "  -f                               force overwriting conflicting files"
	echo "  -h                               print this help list"
	echo "  -o                               only try to clone/update repository if online"
	echo "  -q                               quiet: only output errors, do not overwrite files"
	echo "  -u <name>                        unlink all config files of a program"
	echo "  -v                               increase verbosity of output"
	echo
	echo "Initial setup:"
	echo " - Create a git repository somewhere (e.g., on github)"
	echo " - Edit the $0 file:"
	echo "   - Set variable \$REPOSITORY, to reflect the location of your git repository"
	echo "   - Set variable \$DOT, the local clone of your git repository"
	echo
	echo " - Current configuration:"
	echo "   - \$REPOSITORY = $REPOSITORY"
	echo "   - \$DOT        = $DOT"
	echo
	echo " - Add vim to git-repository and create symlinks in place of the original files:"
	echo "     $ $0 -a vim .vimrc .vim/colors/summerfruit256.vim"
	echo "   - Now go to your \$DOT directory and commit the files"
	echo "   - On other machines run $0 without arguments to"
	echo "     update and link config files from repository"
	echo
	echo " - Remove vim from repository and restore regular config files:"
	echo "   $ $0 -u vim"
	echo "   - The config files will remain in \$REPOSITORY"
	echo "   - The original config file locations (symlinks) are replaced with copies from \$REPOSITORY."
	echo
	echo "Report bugs to: <miller@kit.edu>"
	echo

	exit
fi


# exit if...
# ... configuration is incomplete or
# ... if contradicting flags were given
environment_check


if [[ $ADD -eq 1 ]]
then
	add $@
elif [[ $UNLINK -eq 1 ]]
then
	unlink $@
else
	[ ! -z "$1" ] && fail "You unexpectedly provided additional arguments, exiting" && exit
	setup
fi

exit 0

