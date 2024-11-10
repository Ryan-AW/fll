#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"
output=""


_db_dump() {
	# takes in nothing
	# returns:
	# 0 if the database is not empty
	# 1 if the databse is empty 

	local table
	table=$(cat "$db_path")
	if [[ $table ]]; then
		printf "$table"
		return 0
	else
		echo "AliasNotFound: No Aliases Found"
		return 1
	fi
}
_db_get_path() {
	# takes in the alias
	# sets output = path of alias
	# returns:
	# 0 if alias found
	# 1 if alias not found

	local result
	result=$(awk -v key="$1" 'BEGIN {FS=", "; OFS=", "} $1 == key {line = substr($0, index($0, ", ") + 2)} END {print line}' "$db_path")

	if [ -n "$result" ]; then
		output="$result"
		return 0
	else
		echo "AliasNotFound: '$1'"
		return 1
	fi
}
_db_set_alias() {
	# takes in the alias and a path
	# returns:
	# 0 if the alias name is valid
	# 1 if the alias can't be saved due to having an invalid name

	if [[ "$1" =~ ^[[:alnum:].-_]*$ ]]; then
		_db_remove_alias "$1" > /dev/null
		echo "$1, $(readlink -f "$2")" >> "$db_path"
		return 0
	else
		echo "'$1' is not a valid name for an alias"
		return 1
	fi
}
_db_remove_alias() {
	# takes in the alias
	# returns:
	# 0 if the alias was deleted successfully
	# 1 if the alias was not found

	before=$(grep -c "^$1" "$db_path")
	sed -i "/^$1, /d" "$db_path"
	after=$(grep -c "^$1" "$db_path")

	if [ $before -le $after ]; then
		echo "AliasNotFound: '$1'"
		return 1
	fi
	return 0
}
_db_remove_cwd() {
	# takes in nothing
	# returns:
	# 0 if an alias was deleted successfully
	# 1 if an alias was not found

	local temp_file
	temp_file=$(mktemp)

	grep -v ", $(pwd)$" "$db_path" > "$temp_file"

	if cmp "$db_path" "$temp_file" > /dev/null; then
		echo "AliasNotFound: No aliases set to current directory found"
		return 1
	else
		mv "$temp_file" "$db_path"
		return 0
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
