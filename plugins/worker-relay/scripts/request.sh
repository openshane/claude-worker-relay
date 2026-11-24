# Common arguments for the two Claude Code workers.
parse_request() {
    session_id=
    if [[ ${1:-} == --resume ]]; then
        if [[ ! ${2:-} =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$ ]]; then
            echo '--resume requires the session_id from a previous reply' >&2
            return 2
        fi
        # The CLIs report lowercase IDs, which the reply check compares exactly.
        session_id=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
        shift 2
    fi
    if [[ $# != 2 || -z $1 ]]; then
        echo "Usage: bash ${0##*/} [--resume SESSION_ID] DIRECTORY 'TASK'  (use - to read TASK from stdin)" >&2
        return 2
    fi
    cd -- "$1"
    prompt=$2
    if [[ $prompt == - ]]; then
        # Read through EOF, retaining quotes and trailing newlines.
        IFS= read -r -d '' prompt || true
    fi
    if [[ ! $prompt =~ [^[:space:]] ]]; then
        echo 'Task must not be blank' >&2
        return 2
    fi
}
