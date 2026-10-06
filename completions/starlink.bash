_starlink()
{
    local current previous value
    COMPREPLY=()
    current=${COMP_WORDS[COMP_CWORD]}
    previous=${COMP_WORDS[COMP_CWORD-1]}

    if [[ $previous == -s || $previous == --sort ]]; then
        while IFS= read -r value; do
            COMPREPLY+=("$value")
        done < <(compgen -W 'hostname ip' -- "$current")
        return
    fi

    [[ $previous == --router ]] && return

    while IFS= read -r value; do
        COMPREPLY+=("$value")
    done < <(compgen -W '-s --sort --router --json -h --help -V --version' -- "$current")
}
complete -F _starlink starlink
