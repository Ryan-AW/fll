#!/bin/bash
# This should be ran as a bash source file


if [[ -z "$ZSH_VERSION" ]]; then
    IFS=',' read -ra lines <<< "$*"
else
    IFS=',' read -rA lines <<< "$*"
    setopt BASH_REMATCH
    setopt KSH_ARRAYS
fi

db_path="$(dirname "$BASH_SOURCE")/pathlinks.db"

    
if [[ "${lines[*]}" =~ [[:space:]]*--reset[[:space:]]* ]]; then
    rm "$db_path"
    sqlite3 --separator " <--- " "$db_path" "CREATE TABLE links (keyword text, path text, unique(keyword));"
elif [[ "${lines[*]}" =~ [[:space:]]*--help[[:space:]]* ]]; then
    echo "Usage: fll [OPTIONS | SCRIPT]"
    echo
    echo "Options:"
    echo "--help        Show this help message and exit"
    echo "--reset       Reset the database (WARNING: this will delete all data) and exit"
    echo
    echo "SCRIPT        The script to execute, written with fll syntax"

else
    counter=0
    for line in "${lines[@]}"; do
	counter=$((counter + 1))

        if [[ $line =~ ^[[:space:]]*$ ]]; then
		:

	elif [[ $line =~ ^[[:space:]]*(.)[[:space:]]*$ ]]; then
                if [ ${BASH_REMATCH[1]} = ":" ]; then
			sqlite3 --separator " <--- " "$db_path" "SELECT * FROM links"

                elif [ ${BASH_REMATCH[1]} = "^" ]; then
			sqlite3 --separator " <--- " "$db_path" "DELETE FROM links WHERE path = \"$(pwd)\""

		else
			echo "UnknownSystemCommand [line $counter]: \"${BASH_REMATCH[1]}\""
			break
		fi

        elif [[ $line == *"="* ]]; then
                if [[ $line =~ ^[[:space:]]*[^[:space:]][[:space:]]*= ]]; then
			echo "InvalidAssignmentError [line $counter]: variable name must be at least 2 characters"
			break

		elif [[ $line =~ ^[[:space:]]*([^[:space:]]{2,})[[:space:]]*=[[:space:]]*$ ]]; then
			sqlite3 --separator " <--- " "$db_path" "REPLACE INTO links VALUES (\"${BASH_REMATCH[1]}\", \"$(pwd)\")"

                elif [[ $line =~ ^[[:space:]]*[^[:space:]]{2,}[[:space:]]*=[[:space:]]*:[^[:space:]][:space:]*$ ]]; then
			echo "IntervariableAssignmentError [line $counter]: other variable name must be at least 2 characters"
			break

		elif [[ $line =~ ^[[:space:]]*([^[:space:]]{2,})[[:space:]]*=[[:space:]]*:([^[:space:]]{2,})[:space:]*$ ]]; then
			sqlite3 --separator " <--- " "$db_path" "REPLACE INTO links VALUES (\"${BASH_REMATCH[1]}\", \"$(sqlite3 --separator " <--- " "$db_path" "SELECT path FROM links WHERE keyword = '${BASH_REMATCH[2]}'")\")"

		elif [[ $line =~ ^[[:space:]]*([^[:space:]]{2,})[[:space:]]*=[[:space:]]*([^[:space:]]+)[:space:]*$ ]]; then
			sqlite3 --separator " <--- " "$db_path" "REPLACE INTO links VALUES (\"${BASH_REMATCH[1]}\", \"$(readlink -f "${BASH_REMATCH[2]}")\")"
		else
			echo "InvalidAssignment [line $counter]"
		fi

	elif [[ $line =~ ^[[:space:]]*(.)([^[:space:]]+)[[:space:]]*$ ]]; then
		if [ ${BASH_REMATCH[1]} = ":" ]; then
			sqlite3 --separator " <--- " "$db_path" "SELECT * FROM links WHERE keyword = \"${BASH_REMATCH[2]}\""
		elif [ ${BASH_REMATCH[1]} = "^" ]; then
			sqlite3 --separator " <--- " "$db_path" "DELETE FROM links WHERE keyword = \"${BASH_REMATCH[2]}\""
		else
			cd "$(sqlite3 --separator " <--- " "$db_path" "SELECT path FROM links WHERE keyword = \"${BASH_REMATCH[1]}${BASH_REMATCH[2]}\"")"
		fi

        else
		echo "SyntaxError [line $counter]: $line"
		break
        fi
    done
    
    unset counter
    unset line
    unset IFS
fi

unset db_path
unset lines

if [[ "$ZSH_VERSION" ]]; then
    unsetopt BASH_REMATCH
    unsetopt KSH_ARRAYS
fi
