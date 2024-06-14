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
		COMPREPLY=( $(compgen -W "$completions --help --print --script" -- $cur) )
	fi

	if [ $COMP_CWORD -eq 2 ]; then
		case "$prev" in
			--help|-h);;
			--print|-p)
				completions=$(sqlite3 "$db_path" "SELECT keyword FROM aliases")
				COMPREPLY=( $(compgen -W "$completions" -- $cur) );;
			--script|-l)
				COMPREPLY=( $(compgen -f -- $cur) );;
			*)
			COMPREPLY=( $(compgen -W "$(compgen -f -- $cur) --print" -- $cur) );;
		esac
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





_help() {
	# takes in all arguments
	# returns:
	# 0 to continue
	# 2 if success but the program should halt
	for arg in "$@"; do
		if [ "$arg" = "-h" -o "$arg" = "--help" ]; then
			echo "help menu not written yet"
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
			_db_get_all && echo "$output" && return 2
			return 1
		fi
	elif [[ "$2" == "--print" || "$2" == "-p" ]]; then
		_db_get_path "$1" && echo "$output" && return 2
		return 1
	fi
}



_help "$@" &&
_script "$1" &&
_print "$1" "$2"
echo "return code '$?'"
