#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"
output=""
script_name=""
script=""




_fll_min_completion() {
	local cur prev aliases mode lines args cur_line

	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	aliases="$(sqlite3 "$db_path" "SELECT keyword FROM aliases")"


	if [ $COMP_CWORD -eq 1 ]; then
		if [[ "$cur" == -* ]]; then
			COMPREPLY=( $(compgen -W "$(compgen -d -- "$cur") --print --remove --help --script" -- $cur) )
		else
			COMPREPLY=( $(compgen -W "$aliases" -- $cur) )
		fi
		return 0

	elif [ $COMP_CWORD -eq 2 ]; then
		case "$prev" in
			--help|-h)
				return 0;;
			--script|-s)
				COMPREPLY=( $(compgen -W "$aliases" -- $cur) )
				return 0;;
			--print|-p|--remove|-r)
				COMPREPLY=( $(compgen -W "$aliases" -- $cur) )
				return 0;;
			*)
				if [[ "$cur" == -* ]]; then
					COMPREPLY=( $(compgen -W "$(compgen -d -- "$cur") --print --remove" -- $cur) )
				else
					COMPREPLY=( $(compgen -d -- "$cur") )
				fi
				return 0;;
		esac
	fi

        if [[ "${COMP_WORDS[1]}" =~ (-s|--script) ]]; then
		if [[ "$prev" == "=" ]]; then
			COMPREPLY=( $(compgen -d -- "$cur") )
		else
			COMPREPLY=( $(compgen -W "$aliases" -- $cur) )
		fi
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
	test_if_exists=$(sqlite3 "$db_path" "SELECT script FROM templates WHERE keyword = '$1'")

	if [ -z "test_if_exists" ]; then
		echo "TemplateNotFound: '$1'"
		return 1
	fi
}
print_template() {
	# takes in the template name
	# sets output = the script
	# returns 1 if error

	output=$(sqlite3 "$db_path" "SELECT script FROM templates WHERE keyword = '$1'")

	if [ -z "$output" ]; then
		echo "TemplateNotFound: '$1'"
		return 1
	fi
}








_script_blank_line() {
	# takes in one line of script
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

	if [[ "$1" =~ ^[[:space:]]*$ ]]; then
		echo "empty line"
	fi
}

_script_assignment() {
	# takes in one line of script and the line number
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

	if [[ "$1" == *"="* ]]; then
		if [[ "$1" =~ ^.*[:^].*= ]]; then
			echo "InvalidAssignmentError [line $2]: ':' and '^' are reserved keywords"
			return 1

		elif [[ "$1" =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*$ ]]; then
			_db_set_alias "${BASH_REMATCH[1]}" "$(pwd)" && return 2
			return "$?"

		elif [[ "$1" =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*:[[:space:]]*([[:alnum:].-_]+)[[:space:]]*$ ]]; then
			_db_get_path "${BASH_REMATCH[2]}" && _db_set_alias "${BASH_REMATCH[1]}" "$output" && return 2
			return 1


		elif [[ "$1" =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*([[:alnum:].-_]+)[[:space:]]*$ ]]; then
			_db_set_alias "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" && return 2
			return "$?"
		else
			echo "InvalidAssignment [line $2]: '$1'"
			return 1
		fi
	fi
}

_script_print() {
	# takes in one line of script and the line number
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

        if [[ "$1" =~ ^[[:space:]]*:[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		if [[ ${BASH_REMATCH[1]} ]]; then
			_db_get_path "${BASH_REMATCH[1]}" && echo "$output" && return 2
		else
			_db_dump && echo "$output" && return 2
			return 1
		fi
	fi
}


_script_remove() {
	# takes in one line of script and the line number
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

        if [[ "$1" =~ ^[[:space:]]*\^[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		if [[ ${BASH_REMATCH[1]} ]]; then
			_db_remove_alias "${BASH_REMATCH[1]}" && echo "$output" && return 2
		else
			_db_remove_cwd && return 2
		fi
		return 1
	fi
}


_script_alias() {
	# takes in one line of script
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

        if [[ "$1" =~ ^[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		_goto_alias "${BASH_REMATCH[1]}" && return 2
		return 1
	fi
}

_script_template() {
	# takes in one line of script and the line number
	# returns:
	# 0 to continue script
	# 1 if error
	# 2 to continue to next line

	if [[ $line =~ ^[[:space:]]*([[:alnum:].-_]*)[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		if [ ${BASH_REMATCH[1]} = "def" ]; then
			script_name="${BASH_REMATCH[2]}"
			script=""

                elif [ ${BASH_REMATCH[1]} = "del" ]; then
			_del_template "${BASH_REMATCH[2]}" && return 2
			return 1

                elif [ ${BASH_REMATCH[1]} = "run" ]; then
			_get_template "${BASH_REMATCH[2]}" "$2" && return 2
			return 1

                elif [ ${BASH_REMATCH[1]} = "print" ]; then
			if [[ "${BASH_REMATCH[2]}" == ":" ]]; then
				_dump_templates && return 2
				return 1
			else
				_print_template "${BASH_REMATCH[2]}" && return 2
			fi
			return 1

                elif [ ${BASH_REMATCH[1]} = "end" ]; then
                        if [ ${BASH_REMATCH[2]} = "def" ]; then
                                if [ -z "$script_name" ]; then
                                        echo "No starting def"
					return 1
				else
					sqlite3 --separator " <--- " "$db_path" "REPLACE INTO templates VALUES ('$script_name', '$script')"
					script=""
					script_name=""
				fi
                        else
                                echo "only 'def' can be ended, correct syntax is 'end def'"
                        fi
                else
                        echo "SyntaxError [line $counter]: $line"
                fi
	fi
}


_script_invalid_syntax() {
	# takes in one line of script and the line number
	# returns 1

	echo "SyntaxError"
	return 1
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
			echo "	'<newAlias> = :<existingAlias>' sets an alias to the value of an already existing alias"
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
_script() {
	# takes in the all arguments
	# returns:
	# 0 to continue
	# 1 if error
	# 2 if success but the program should halt

	local lines counter line
	if [[ "$1" =~ (-s|--script) ]]; then
		shift
		if [[ -z "$ZSH_VERSION" ]]; then
			IFS=',' read -ra lines <<< "$*"
		else
			IFS=',' read -rA lines <<< "$*"
		fi

		counter=0
		while [ $counter -lt ${#lines[@]} ]; do
			line="${lines[$counter]}"
			((counter++))

			_script_blank_line "$line" &&
			_script_assignment "$line" "$counter" &&
			_script_print "$line" "$counter" &&
			_script_remove "$line" &&
			_script_alias "$line" &&
			_script_template "$line" "$counter" &&
			_script_invalid_syntax "$line" "$counter"

			if [ "$script_name" ]; then
				if [ "$script" = "," ]; then
					script="$line"
				elif [ "$script" ]; then
					script="$script, $line"
				else
					script=","
				fi
			fi

			if [[ "$?" == 1 ]]; then
				return 1
			fi
		done
		return 2
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
_script "$@" &&
_print "$1" "$2" &&
_remove "$1" "$2" &&
_handle_aliases "$1" "$2"

if [[ "$ZSH_VERSION" ]]; then
	unsetopt BASH_REMATCH
fi
