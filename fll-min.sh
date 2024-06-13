#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"
output=""



_fll_min_completion() {
	local cur prev completions
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	if [ $COMP_CWORD -eq 1 ]; then
		completions=$(sqlite3 "$db_path" "SELECT keyword FROM aliases")
		COMPREPLY=( $(compgen -W "$completions" -- $cur) )
	fi

	if [ $COMP_CWORD -eq 2 ]; then
		COMPREPLY=( $(compgen -f -- $cur) )
	fi

	return 0
}
complete -F _fll_min_completion fll


_db_get_all() {
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
	# takes in the keyword
	# sets output = path of keyword
	# returns 1 if keyword not found

	local new_path
	new_path=$(sqlite3 "$db_path" "SELECT path FROM aliases WHERE keyword = '$1'")
	if [[ $new_path ]]; then
		output="$new_path"
	else
		echo "AliasNotFound: '$1'"
		return 1
	fi
}


_show() {
	# takes in the first two arguments
	# returns:
	# 0 to continue
	# 1 if error
	# 2 if success but the program should halt
	if [[ "$1" == "--show" || "$1" == "-s" ]]; then
		if [[ "$2" == "--show" || "$2" == "-s" ]]; then
			echo "Error: you can only use the --show/-s flag once"
			return 1
		elif [[ "$2" ]]; then
			_db_get_path "$2" && echo "$output" && return 2
			return 1
		else
			_db_get_all && echo "$output" && return 2
			return 1
		fi
	elif [[ "$2" == "--show" || "$2" == "-s" ]]; then
		_db_get_path "$1" && echo "$output" && return 2
		return 1
	fi
}

_show "$1" "$2"
echo "return code '$?'"
