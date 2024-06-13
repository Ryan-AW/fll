#!/bin/bash

db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"



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

if [ $# -eq 0 ]; then
  echo "Error: No options provided."

elif [ $# -eq 1 ]; then
	new_path=$(sqlite3 --separator " <--- " "$db_path" "SELECT path FROM aliases WHERE keyword = '$1'")
	if [[ $new_path ]]; then
		cd "$new_path"
	else
		echo "AliasNotFound: '$1'"
	fi

elif [ $# -eq 2 ]; then
  sqlite3 "$db_path" "REPLACE INTO aliases VALUES ('$1', '$(readlink -f "$2")')"

else
  echo "Error: Too many options. Only 2 allowed."
fi
