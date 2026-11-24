#!/usr/bin/env bash
set -euo pipefail
agent_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
mkdir "$test_root/work tree"
trap 'rm -rf -- "$test_root"' EXIT
export test_cwd=$(cd "$test_root/work tree" && pwd -P)
git -C "$test_cwd" init -q
# An uncommitted file that exists before the call must not count as a change by Gemini.
echo existing > "$test_cwd/existing.txt"
export test_id=01234567-1234-4321-abcd-0123456789ab
unset CODEX_WORKER_MODEL CODEX_WORKER_EFFORT
export test_prompt=$'任务 "quotes" $HOME ; `echo literal`\nsecond line\n'

# Exercise the public Bash commands with the same stdin/stdout protocol as each CLI.
agy() {
    [[ $(pwd -P) == "$test_cwd" ]] || return 9
    local expected=(--mode plan --input-format stream-json --output-format stream-json)
    if [[ $test_mode == resume ]]; then expected+=(--conversation "$test_id"); fi
    [[ "$*" == "${expected[*]}" ]] || return 9
    node --input-type=module -e '
        import assert from "node:assert/strict";
        import { text } from "node:stream/consumers";
        const request = JSON.parse(await text(process.stdin));
        assert.deepEqual(Object.keys(request), ["event", "message"]);
        assert.equal(request.event, "user");
        const content = request.message.content;
        assert.ok(content.endsWith(`\n\nRequest:\n${process.env.test_prompt}`));
        assert.match(content, /do not create, modify or delete any file/);
        assert.match(content, process.env.test_mode === "copy" ? /Copy changes/ : /Conclusion/);
    ' || return 9
    echo 'Loading credentials...'
    printf '{"event":"init","conversation_id":"%s"}\n' "$test_id"
    case "$test_mode" in
        truncated) return 0 ;;
        failure) echo '{"event":"result","result":{"status":"ERROR","error":"test failure"}}'; return 0 ;;
        writes) echo changed > hacked.txt; echo more >> existing.txt ;;
    esac
    printf '{"event":"result","result":{"conversation_id":"%s","status":"SUCCESS","response":"回答\\nOK"}}\n' "$test_id"
    [[ $test_mode != bad_exit ]]
}
codex() {
    [[ $(pwd -P) == "$test_cwd" ]] || return 9
    local expected=(exec)
    if [[ $test_mode == resume ]]; then expected+=(resume); fi
    expected+=(--json --ignore-user-config --disable apps --disable plugins --disable remote_plugin
        -c 'sandbox_mode="workspace-write"' -c 'approval_policy="never"' -c 'model_reasoning_effort="xhigh"')
    if [[ $test_mode == resume ]]; then expected+=(-m test-model); fi
    if [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]]; then expected+=(-c 'windows.sandbox="elevated"'); fi
    if [[ $test_mode == resume ]]; then expected+=("$test_id"); fi
    expected+=(-)
    [[ "$*" == "${expected[*]}" ]] || return 9
    local content
    IFS= read -r -d '' content || true
    [[ $content == "$test_prompt" ]] || return 9
    echo 'WARNING: proceeding, even though we could not update PATH'
    printf '{"type":"thread.started","thread_id":"%s"}\n' "$test_id"
    echo '{"type":"item.completed","item":{"type":"agent_message","text":"progress"}}'
    echo '{"type":"item.completed","item":{"type":"agent_message","text":"回答\nOK"}}'
    case "$test_mode" in
        truncated) return 0 ;;
        failure) echo '{"type":"turn.failed","error":{"message":"test failure"}}'; return 0 ;;
    esac
    echo '{"type":"turn.completed","usage":{}}'
    [[ $test_mode != bad_exit ]]
}
export -f agy codex
export test_mode

check_reply() {
    printf '%s' "$1" | node --input-type=module -e '
        import assert from "node:assert/strict";
        import { text } from "node:stream/consumers";
        const reply = JSON.parse(await text(process.stdin));
        assert.deepEqual(reply, { session_id: process.env.test_id, reply: "回答\nOK" });
    '
}
fail() {
    echo "$*" >&2
    exit 1
}

for entry in agy-ask codex-worker; do
    # First request with a stray non-JSON line, then a resume given an uppercase ID.
    test_mode=first
    errors=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>&1 >"$test_root/out") || fail "$entry failed: $errors"
    check_reply "$(<"$test_root/out")"
    [[ $errors == *'ignored non-JSON output'* ]] || fail "$entry did not report the non-JSON line"
    [[ $errors != *'changed these files'* ]] || fail "$entry reported a pre-existing file as changed"
    test_mode=resume
    upper_id=$(printf '%s' "$test_id" | tr '[:lower:]' '[:upper:]')
    response=$(printf '%s' "$test_prompt" |
        CODEX_WORKER_MODEL=test-model bash "$agent_dir/$entry" --resume "$upper_id" "$test_cwd" - 2>/dev/null)
    check_reply "$response"
    for test_mode in truncated failure bad_exit; do
        if response=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>/dev/null); then
            fail "$entry unexpectedly succeeded in $test_mode"
        fi
        [[ -z $response ]]
    done
    if [[ $entry == codex-worker ]]; then
        # A stopped run must still leave the session ID on stderr.
        test_mode=truncated
        errors=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>&1 >/dev/null || true)
        [[ $errors == *"codex: session_id $test_id"* ]] || fail 'codex-worker did not report the session ID early'
    else
        test_mode=copy
        response=$(bash "$agent_dir/$entry" --copy "$test_cwd" "$test_prompt" 2>/dev/null)
        check_reply "$response"
        # Files written despite the read-only instruction give exit code 3 and keep the reply.
        test_mode=writes
        status=0
        response=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>"$test_root/err") || status=$?
        (( status == 3 )) || fail "agy-ask exited $status after Gemini wrote files"
        check_reply "$response"
        grep -q $'^A\thacked.txt$' "$test_root/err" || fail 'agy-ask did not list the new file'
        grep -q $'^M\texisting.txt$' "$test_root/err" || fail 'agy-ask did not list the modified file'
        rm -- "$test_cwd/hacked.txt"
    fi
    printf 'PASS %s\n' "$entry"
done
