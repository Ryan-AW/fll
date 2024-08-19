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







_get_template() {
	# takes in the template name and line count
	# sets output = template content
	# returns 1 if error

	output=$(sqlite3 "$db_path" "SELECT script FROM templates WHERE keyword = '$1'")

	if [ "$output" ]; then
		if [[ -z "$ZSH_VERSION" ]]; then
		    IFS=',' read -ra template <<< "$output"
		else
		    IFS=',' read -rA template <<< "$output"
		fi

		lines=("${lines[@]:0:$2}" "${template[@]}" "${lines[@]:$2}")
	else
		echo "TemplateNotFound: '${BASH_REMATCH[2]}'"
		return 1
	fi
}

_del_template() {
	# takes in the template name
	# returns 1 if error

	local test_if_exists
	test_if_exists=$(sqlite3 "$db_path" "SELECT 1 FROM templates WHERE keyword = '$1'; DELETE FROM templates WHERE keyword = '$1';")

	if [ -z "$test_if_exists" ]; then
		echo "TemplateNotFound: '$1'"
		return 1
	fi
}
_dump_templates() {
	# returns 1 if error

	local test_if_exists
	test_if_exists=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM templates")

	if [ -z "$test_if_exists" ]; then
		echo "TemplateNotFound: No Templates Found"
		return 1
	else
		echo "$test_if_exists"
	fi
}
_print_template() {
	# takes in the template name
	# sets output = the script
	# returns 1 if error

	output=$(sqlite3 "$db_path" "SELECT script FROM templates WHERE keyword = '$1'")

	if [ -z "$output" ]; then
		echo "TemplateNotFound: '$1'"
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
			echo 'Usage: fll [options] <alias> <path>'
			echo 'Or usage: fll --script/-s [fll SCRIPT ...]'
			echo
			echo 'Options:'
			echo '  -h, --help     Show this help menu'
			echo '  -p, --print    Print the alias'
			echo '  -r, --remove   Remove the alias'
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
			echo '  fll -r          Unassigns all aliases that point to the current working directory'
			echo '  fll -r myalias  Unassigns "myalias"'
			echo '  fll myalias /path/to/save  Set the path for "myalias" to "/path/to/save"'
			echo '  fll -s          Enter FLL scripting mode (all following commands will be interpreted as FLL)'
			echo
			echo "SCRIPT syntax"
			echo
			echo "to run multiple commands in a row separate them with ','"
			echo "e.g. fll -s home = /home/, :home"
			echo
			echo "System commands:"
			echo "	':'     show all aliases"
			echo "	'^'     delete all aliases that link to the current directory"
			echo
			echo "Alias assignment:"
			echo "	'<alias> = '                         sets an alias to the current path"
			echo "	'<alias> = directory_path'           sets an alias to the specified path"
			echo "	'<newAlias> = :<existingAlias>'      sets an alias to the value of an already existing alias"
			echo
			echo "Statements:"
			echo "	'<alias>'    changes directory using the alias"
			echo "	':<alias>'   shows what the specified alias is"
			echo "	'^<alias>'   removes specified alias"
			echo
			echo "Templates:"
			echo "	'def <template>'		starts recording template"
			echo "	'end def'			stop recording template and saves it"
			echo "	'run <template>'		execute the specified template"
			echo
			echo "	'del <template>'		deletes specified template"
			echo "	'print <template>'		displays specified template"
			echo "	'print :'			displays all templates"

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
unset _get_template
unset _del_template
unset _dump_templates
unset _print_template
unset _help
unset _print
unset _remove
unset _handle_aliases
