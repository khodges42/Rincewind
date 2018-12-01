#!/bin/bash

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}

begins_with_short_option()
{
	local first_option all_short_options
	all_short_options='eh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}



# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_environment=

print_help ()
{
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s [-e|--environment <arg>] [-h|--help] <action> <project>\n' "$0"
	printf '\t%s\n' "<action>: use, cd, start, init, delete, ls, envs, add-env"
	printf '\t%s\n' "<project>: name of project"
	printf '\t%s\n' "-e,--environment: The environment to use, default is blank (no default)"
	printf '\t%s\n' "-h,--help: Prints help"
}

parse_commandline ()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-e|--environment)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_environment="$2"
				shift
				;;
			--environment=*)
				_arg_environment="${_key##--environment=}"
				;;
			-e*)
				_arg_environment="${_key##-e}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_positionals+=("$1")
				;;
		esac
		shift
	done
}


handle_passed_args_count ()
{
	_required_args_string="'action' and 'project'"
	test ${#_positionals[@]} -ge 2 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 2 (namely: $_required_args_string), but got only ${#_positionals[@]}." 1
	test ${#_positionals[@]} -le 2 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 2 (namely: $_required_args_string), but got ${#_positionals[@]} (the last one was: '${_positionals[*]: -1}')." 1
}

assign_positional_args ()
{
	_positional_names=('_arg_action' '_arg_project' )

	for (( ii = 0; ii < ${#_positionals[@]}; ii++))
	do
		eval "${_positional_names[ii]}=\${_positionals[ii]}" || die "Error during argument parsing, possibly an Argbash bug." 1
	done
}

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

execute_action ()
{
    case "$_arg_action" in
	ls|LS|list|LIST)
	    action_ls
	    ;;
	use|USE)
	    action_use
	    ;;
	env|ENV|envs|ENVS|environment|ENVIRONMENT)
	    echo "env"
	    ;;
	active|ACTIVE)
	    action_active
	    ;;
	env-add|ENV-ADD|add|ADD)
	    echo "add env"
	    ;;
	start|START)
	    echo "start"
	    ;;
	init|INIT)
	    action_init
	    ;;
	setup|SETUP|install|INSTALL)
	    action_setup
	    ;;
	*)
	    
	    print_help
	    ;;
	esac
}

get_envs ()
{
    if [ ! -d "$HOME/.rincewind" ]; then
	if [[ "yes" == $(ask_yes_or_no "Couldn't find $HOME/.rincewind/ , run setup?") ]]; then
	    action_setup
	else
	    echo "Can't continue without $HOME/.rincewind/"
	fi
    else
	rw_project=$(ls -A  $HOME/.rincewind/projects)
    fi
}

verify_symlink()
{
if [ -L $HOME/.rincewind/projects/$_arg_project/projecthome ]; then
	    ls -l $HOME/.rincewind/projects/$_arg_project/projecthome | awk '{print $NF}'
	else
	    echo "Couldn't find that project."
	    echo
	    echo "__Rincewind Projects__"
	    for i in "$rw_project"
	    do
		echo "$i"
	    done
	    exit 1
	 fi
}

action_ls ()
{
    if [[ -z $_arg_project ]]; then
	echo "__Rincewind Projects__"
	for i in "$rw_project"
	do
	    echo "$i"
	done
    else
	verify_symlink
    fi
    
}

action_active ()
{
    project_location=$(ls -l $HOME/.rincewind/active | awk '{print $NF}')
    active_name=$(cat $HOME/.rincewind/.active_name)
    echo "$active_name is active, located at $project_location"
}

action_init ()
{
    handle_passed_args_count
    if [ -d "$HOME/.rincewind/projects/$_arg_project" ]; then
	if [[ "no" == $(ask_yes_or_no "You've already got a project with that name. Overwrite?") ]]; then
	    echo "Couldn't continue with init, project exists"
	    
	fi
    fi
    
    mkdir -p $HOME/.rincewind/projects/$_arg_project
    ln -s "$PWD" $HOME/.rincewind/projects/$_arg_project/projecthome
    echo "Created $_arg_project"
}

action_use()
{
    project_location=$(ls -l $HOME/.rincewind/projects/$_arg_project/projecthome | awk '{print $NF}')
    if [ -d "$project_location" ]; then
	ln -sfn "$project_location" "$HOME/.rincewind/active"
	echo $project_location > $HOME/.rincewind/.active_dir
	echo $_arg_project > $HOME/.rincewind/.active_name
	echo "Now using $_arg_project"
    else
	echo "Failed, folder doesnt exist: $project_location"
    fi
    
}

action_setup()
{
    echo "Setting up Rincewind."
    mkdir -p $HOME/.rincewind
    mkdir -p $HOME/.rincewind/projects/
    touch $HOME/.rincewind/config
    ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
    ln -s $ABSOLUTE_PATH $HOME/.rincewind/rincewind.sh
    cp $SCRIPTPATH/default_config $HOME/.rincewind/config
    case "$SHELL" in
	/bin/zsh|zsh)
	    usrshellconf="$HOME/.zshrc"
	    ;;
	/bin/bash)
	    usrshellconf="$HOME/.bashrc"
	    ;;
	*)
	    echo "Cant find user shell"
	    exit 1
	    ;;
    esac

    if ! grep -q "$HOME/.rincewind/config" "$usrshellconf"; then
	echo >> "$usrshellconf"
	echo "# Rincewind config" >> "$usrshellconf"
	

	echo "alias rincewind=$HOME/.rincewind/rincewind.sh" >> "$usrshellconf"
	echo "alias rwcd=\"cd -P $HOME/.rincewind/active\"" >> "$usrshellconf"
    else
	echo "Config already sourced in $usrshellconf"
    fi
    
}


parse_commandline "$@"
assign_positional_args
get_envs
execute_action
