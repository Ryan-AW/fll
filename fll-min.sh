#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"
output=""




_fll_min_completion() {
	local cur prev completions mode
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"


	if [ $COMP_CWORD -eq 1 ]; then
		completions=$(sqlite3 "$db_path" "SELECT keyword FROM aliases")
		COMPREPLY=( $(compgen -W "$completions --help --print --remove --script" -- $cur) )
	fi

	if [ $COMP_CWORD -eq 2 ]; then
		case "$prev" in
			--help|-h);;
			--print|-p|--remove|-r)
				completions=$(sqlite3 "$db_path" "SELECT keyword FROM aliases")
				COMPREPLY=( $(compgen -W "$completions" -- $cur) );;
			--script|-l)
				COMPREPLY=( $(compgen -f -- $cur) );;
			*)
			COMPREPLY=( $(compgen -W "$(compgen -f -- $cur) --print --remove" -- $cur) );;
		esac
	fi
	return 0
}
complete -F _fll_min_completion fll



_db_dump() {
	# takes in nothing
	# sets output = list of (keyword, path)
	# returns 1 if table is empty

	local table
	table=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM aliases")
	if [[ $table ]]; then
		output="$table"
	else
		echo "AliasNotFound: No Aliases Found"
		return 1
	fi
}
_db_get_path() {
	# takes in the alias
	# sets output = path of alias
	# returns 1 if alias not found

	local new_path
	new_path=$(sqlite3 "$db_path" "SELECT path FROM aliases WHERE keyword = '$1'")
	if [[ $new_path ]]; then
		output="$new_path"
	else
		echo "AliasNotFound: '$1'"
		return 1
	fi
}
_db_set_alias() {
	# takes in the alias and a path
	# returns 1 if error

	if [[ "$1" =~ ^[[:alnum:].-_]*$ ]]; then
		sqlite3 "$db_path" "REPLACE INTO aliases VALUES ('$1', '$(readlink -f "$2")')" && return 0
		return 1
	fi
	echo "'$1' is not a valid name for an alias"
	return 1
}
_db_remove_alias() {
	# takes in the alias
	# returns 1 if error

	local test_if_exists
	test_if_exists=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM aliases WHERE keyword = '$1'; DELETE FROM aliases WHERE keyword= '$1';")
	if [ -z "$test_if_exists" ]; then
		echo "AliasNotFound: '$1'"
	fi
}


_goto_alias() {
	# takes in the alias
	# sets output = path of alias
	# returns 1 if error

	_db_get_path "$1" && cd "$output"
	return "$?"
}





_help() {
	# takes in all arguments
	# returns:
	# 0 to continue
	# 2 if success but the program should halt
	for arg in "$@"; do
		if [ "$arg" = "-h" -o "$arg" = "--help" ]; then
			echo 'Usage: fll [options] <alias> <path>'
			echo 'Or usage: fll --script/-s [fll SCRIPT ...]'
			echo
			echo 'Options:'
			echo '  -h, --help     Show this help menu'
			echo '  -p, --print    Print the alias configuration'
			echo '  -r, --remove   Remove the alias configuration'
			echo '  -s, --script   Interpret all following commands as FLL script (must be first argument)'
			echo
			echo 'Arguments:'
			echo '  alias          The alias to manage (required unless using --script)'
			echo '  path           The path to set for the alias (optional)'
			echo
			echo 'Examples:'
			echo '  fll -h          Show this help menu'
			echo '  fll myalias     Change Directory using "myalias" alias'
			echo '  fll -p myalias  Print the path for "myalias"'
			echo '  fll -r myalias  Unassigns "myalias"'
			echo '  fll myalias /path/to/save  Set the path for "myalias" to "/path/to/save"'
			echo '  fll -s          Enter FLL scripting mode (all following commands will be interpreted as FLL)'
			return 2
		fi
	done
}
_script() {
	# takes in the first argument
	# returns:
	# 0 to continue
	# 3 if success

	if [[ "$1" =~ (-s|--script) ]]; then
		echo "it will pass in a script"
		return 3
	fi
}
_print() {
	# takes in the first two arguments
	# returns:
	# 0 to continue
	# 1 if error
	# 2 if success but the program should halt
	
	if [[ "$1" == "--print" || "$1" == "-p" ]]; then
		if [[ "$2" == "--print" || "$2" == "-p" ]]; then
			echo "Error: you can only use the --print/-p flag once"
			return 1
		elif [[ "$2" ]]; then
			_db_get_path "$2" && echo "$output" && return 2
			return 1
		else
			_db_dump && echo "$output" && return 2
			return 1
		fi
	elif [[ "$2" == "--print" || "$2" == "-p" ]]; then
		_db_get_path "$1" && echo "$output" && return 2
		return 1
	fi
}
_remove() {
	# takes in the first two arguments
	# returns:
	# 0 to continue
	# 1 if error
	# 2 if success but the program should halt
	
	if [[ "$1" == "--remove" || "$1" == "-r" ]]; then
		if [[ "$2" == "--remove" || "$2" == "-r" ]]; then
			echo "Error: you can only use the --remove/-r flag once"
			return 1
		elif [[ "$2" ]]; then
			_db_remove_alias "$2" && return 2
			return 1
		else
			echo "you must specify the alias to remove"
			return 1
		fi
	elif [[ "$2" == "--remove" || "$2" == "-r" ]]; then
		_db_remove_alias "$1" && return 2
		return 1
	fi
}
_handle_aliases() {
	# takes in the first two arguments
	# returns:
	# 0 to continue
	# 1 if error
	# 2 if success but the program should halt

	if [[ "$2" ]]; then
		_db_set_alias "$1" "$2" && return 2
		return "$?"
	fi

	if [[ "$1" ]]; then
		_goto_alias "$1" && return 2
		return "$?"
	fi
}



_help "$@" &&
_script "$1" &&
_print "$1" "$2" &&
_remove "$1" "$2" &&
_handle_aliases "$1" "$2"
echo "return code '$?'"
