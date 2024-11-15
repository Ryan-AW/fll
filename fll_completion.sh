#!/bin/bash


_fll_completion() {
	local cur prev aliases mode lines args cur_line db_path
	db_path="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/aliases.db"

	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	aliases=$(cut -d, -f1 "$db_path")


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
	return 0
}
complete -F _fll_completion fll
