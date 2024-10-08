#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"
output=""


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
_db_remove_cwd() {
	# returns 1 if error

	local test_if_exists
	test_if_exists=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM aliases WHERE path = '$(pwd)'; DELETE FROM aliases WHERE path = '$(pwd)';")
	if [ -z "$test_if_exists" ]; then
		echo "AliasNotFound: No aliases set to current directory found"
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
			echo 'Usage: fll [[options] <alias>|<alias> <path>]'
			echo
			echo 'Options:'
			echo '  -h, --help'
			echo '  -p, --print'
			echo '  -r, --remove'
			echo
			echo 'Arguments:'
			echo '  alias          The alias name'
			echo '  path           The path to set the alias (optional)'
			echo
			echo 'Assigning an alias:'
			echo '  fll myAlias /path/to/save  Set the path for "myAlias" to "/path/to/save"'
			echo
			echo 'Using an alias:'
			echo '  fll myAlias     Change directory using "myAlias" alias'
			echo
			echo 'Removing aliases:'
			echo '  fll -r          Unassigns all aliases that point to the current working directory'
			echo '  fll -r myAlias  Unassigns "myAlias"'
			echo
			echo 'Displaying aliases:'
			echo '  fll -p          Print all aliases'
			echo '  fll -p myAlias  Print the path for "myAlias"'
			return 2
		fi
	done
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
			_db_remove_cwd && return 2
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



if [[ "$ZSH_VERSION" ]]; then
	setopt BASH_REMATCH
fi

_help "$@" &&
_print "$1" "$2" &&
_remove "$1" "$2" &&
_handle_aliases "$1" "$2" &&
printf 'No Alias Provided.\nUse `--help` for more info.\n'


if [[ "$ZSH_VERSION" ]]; then
	unsetopt BASH_REMATCH
fi


# unset variables
unset db_path
unset output

# unset functions
unset _db_dump
unset _db_get_path
unset _db_set_alias
unset _db_remove_alias
unset _db_remove_cwd
unset _goto_alias
unset _help
unset _print
unset _remove
unset _handle_aliases
