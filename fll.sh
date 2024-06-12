#!/bin/bash
# This should be ran as a bash source file


if [[ -z "$ZSH_VERSION" ]]; then
    IFS=',' read -ra lines <<< "$*"
else
    IFS=',' read -rA lines <<< "$*"
    setopt BASH_REMATCH
    setopt KSH_ARRAYS
fi

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"

script=""
script_name=""

    
if [[ "${lines[*]}" =~ [[:space:]]*--reset[[:space:]]* ]]; then
    rm "$db_path"
    sqlite3 --separator " <--- " "$db_path" "CREATE TABLE aliases (keyword text, path text, unique(keyword)); CREATE TABLE templates (keyword text, script text, unique(keyword));"

elif [[ "${lines[*]}" =~ [[:space:]]*--help[[:space:]]* ]]; then
    echo "Usage: fll [OPTIONS | SCRIPT]"
    echo
    echo "Options:"
    echo "--help        Show this help message and exit"
    echo "--reset       Reset the database (WARNING: this will delete all data) and exit"
    echo
    echo "SCRIPT syntax"
    echo
    echo "to run multiple commands in a row separate them with ','"
    echo "e.g. fll home = /home/, :home"
    echo
    echo "System commands:"
    echo "	':'     show all aliases"
    echo "	'^'     delete all aliases that link to the current directory"
    echo
    echo "Alias assignment:"
    echo "	'alias_name = '                         sets an alias to the current path"
    echo "	'alias_name = directory_path'           sets an alias to the specified path"
    echo "	'new_alias_name = :existing_alias_name' sets an alias to the value of an already existing alias"
    echo
    echo "Statements:"
    echo "	'alias_name'    changes directory using the alias"
    echo "	':alias_name'   shows what the specified alias is"
    echo "	'^alias_name'   removes specified alias"
    echo
    echo "Templates:"
    echo "	'def <template_name>'		starts recording template"
    echo "	'end def'			stop recording template and saves it"
    echo "	'run <template_name>'		execute the specified template"
    echo
    echo "	'del <template_names>'		deletes specified template"
    echo "	'print <template_names>'	displays specified template"
    echo "	'print +'			displays all templates"


else
    counter=0
    while [ $counter -lt ${#lines[@]} ]; do
	line="${lines[$counter]}"
	((counter++))

        if [[ $line =~ ^[[:space:]]*$ ]]; then
		:

        elif [[ $line == *"="* ]]; then
		if [[ $(echo "$line" | grep -P '^.*[\^:].*=') ]]; then
			echo "InvalidAssignmentError [line $counter]: ':' and '^' are reserved keywords"
			break

		elif [[ $line =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*$ ]]; then
			sqlite3 --separator " <--- " "$db_path" "REPLACE INTO aliases VALUES ('${BASH_REMATCH[1]}', '$(pwd)')"

		elif [[ $line =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*:[[:space:]]*([[:alnum:].-_]+)[[:space:]]*$ ]]; then
			output=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM aliases WHERE keyword = '${BASH_REMATCH[2]}' LIMIT 1")

			if [ -z "$output" ]; then
				echo "AliasNotFound: '${BASH_REMATCH[2]}'"
				break
			else
				output=$(sqlite3 --separator " <--- " "$db_path" "REPLACE INTO aliases VALUES ('${BASH_REMATCH[1]}', (SELECT path FROM aliases WHERE keyword = '${BASH_REMATCH[2]}' LIMIT 1));")
			fi
			unset output


		elif [[ $line =~ ^[[:space:]]*([[:alnum:].-_]+)[[:space:]]*=[[:space:]]*([[:alnum:].-_]+)[[:space:]]*$ ]]; then
			sqlite3 --separator " <--- " "$db_path" "REPLACE INTO aliases VALUES ('${BASH_REMATCH[1]}', '$(readlink -f "${BASH_REMATCH[2]}")')"
		else
			echo "InvalidAssignment [line $counter]: '$line'"
		fi

	elif [[ $line =~ ^[[:space:]]*([:^])[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		if [ ${BASH_REMATCH[1]} = ":" ]; then
			if [ ${BASH_REMATCH[2]} ]; then
				output=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM aliases WHERE keyword = '${BASH_REMATCH[2]}'")
				if [ "$output" ]; then
					echo "$output"
				else
					echo "AliasNotFound: '${BASH_REMATCH[2]}'"
					break
				fi
			else
				output=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM aliases")
				if [ "$output" ]; then
					echo "$output"
				else
					echo "AliasNotFound: No aliases found"
					break
				fi
			fi

			unset output

		elif [ ${BASH_REMATCH[1]} = "^" ]; then
			if [ ${BASH_REMATCH[2]} ]; then
				output=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM aliases WHERE keyword = '${BASH_REMATCH[2]}'; DELETE FROM aliases WHERE keyword = '${BASH_REMATCH[2]}';")
				if [ -z "$output" ]; then
					echo "AliasNotFound: '${BASH_REMATCH[2]}'"
					break
				fi
				unset output
			else
				output=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM aliases WHERE path = '$(pwd)'; DELETE FROM aliases WHERE path = '$(pwd)';")
				if [ -z "$output" ]; then
					echo "AliasNotFound: No aliases set to current directory found"
					break
				fi
				unset output
			fi

		fi

	elif [[ $line =~ ^[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		new_path=$(sqlite3 --separator " <--- " "$db_path" "SELECT path FROM aliases WHERE keyword = '${BASH_REMATCH[1]}'")
		if [[ $new_path ]]; then
			cd "$new_path"
		else
			echo "AliasNotFound: '${BASH_REMATCH[1]}'"
			break
		fi
		unset new_path

	elif [[ $line =~ ^[[:space:]]*([[:alnum:].-_]*)[[:space:]]*([[:alnum:].-_]*)[[:space:]]*$ ]]; then
		if [ ${BASH_REMATCH[1]} = "def" ]; then
			if [ "$script_nanme" ]; then
				echo "'$script_nanme' hasn't endend"
				break
			fi
			script_name="${BASH_REMATCH[2]}"

		elif [ ${BASH_REMATCH[1]} = "del" ]; then
			output=$(sqlite3 --separator " <--- " "$db_path" "SELECT 1 FROM templates WHERE keyword = '${BASH_REMATCH[2]}'; DELETE FROM templates WHERE keyword = '${BASH_REMATCH[2]}';")
			if [ -z "$output" ]; then
				echo "TemplateNotFound: '${BASH_REMATCH[2]}'"
				break
			fi
			unset output

		elif [ ${BASH_REMATCH[1]} = "run" ]; then
			output=$(sqlite3 --separator " <--- " "$db_path" "SELECT script FROM templates WHERE keyword = '${BASH_REMATCH[2]}'")

			if [ "$output" ]; then
				if [[ -z "$ZSH_VERSION" ]]; then
				    IFS=',' read -ra template <<< "$output"
				else
				    IFS=',' read -rA template <<< "$output"
				fi

				lines=("${lines[@]:0:$counter}" "${template[@]}" "${lines[@]:$counter}")
				unset template
			else
				echo "TemplateNotFound: '${BASH_REMATCH[2]}'"
				break
			fi
			unset output

		elif [ ${BASH_REMATCH[1]} = "print" ]; then
			output=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM templates WHERE keyword = '${BASH_REMATCH[2]}'")

			if [ "$output" ]; then
				echo "$output"
			else
				echo "TemplateNotFound: '${BASH_REMATCH[2]}'"
				break
			fi
			unset output

		elif [ ${BASH_REMATCH[1]} = "end" ]; then
			if [ ${BASH_REMATCH[2]} = "def" ]; then
				if [ -z "$script_name" ]; then
					echo "No starting def"
					break
				fi
				sqlite3 --separator " <--- " "$db_path" "REPLACE INTO templates VALUES ('$script_name', '$script')"
				script=""
				script_name=""
			else
				echo "only 'def' can be ended, correct syntax is 'end def'"
			fi
		else
			echo "SyntaxError [line $counter]: $line"
		fi

	elif [[ $line =~ ^[[:space:]]*print[[:space:]]*[+][[:space:]]*$ ]]; then
		output=$(sqlite3 --separator " <--- " "$db_path" "SELECT * FROM templates")

		if [ "$output" ]; then
			echo "$output"
		else
			echo "TemplateNotFound: No templates found"
			break
		fi
		unset output


        else
		echo "SyntaxError [line $counter]: $line"
		break
        fi

	if [ "$script_name" ]; then
		if [ "$script" = "," ]; then
			script="$line"
		elif [ "$script" ]; then
			script="$script, $line"
		else
			script=","
		fi
	fi

    done
    
    unset counter
    unset line
    unset IFS
fi

unset db_path
unset script
unset script_name
unset lines

if [[ "$ZSH_VERSION" ]]; then
    unsetopt BASH_REMATCH
    unsetopt KSH_ARRAYS
fi
