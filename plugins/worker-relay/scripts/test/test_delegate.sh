#!/usr/bin/env bash
set -euo pipefail
agent_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
mkdir "$test_root/work tree"
trap 'rmdir -- "$test_root/work tree" "$test_root"' EXIT
export test_cwd=$(cd "$test_root/work tree" && pwd -P)
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
        assert.deepEqual(request, { event: "user", message: { content: process.env.test_prompt } });
    ' || return 9
    printf '{"event":"init","conversation_id":"%s"}\n' "$test_id"
    case "$test_mode" in
        truncated) return 0 ;;
        failure) echo '{"event":"result","result":{"status":"ERROR","error":"test failure"}}'; return 0 ;;
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
for entry in agy-ask codex-worker; do
    for test_mode in first resume; do
        args=()
        if [[ $test_mode == resume ]]; then args=(--resume "$returned_id"); fi
        if [[ $test_mode == first ]]; then
            response=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt")
        else
            response=$(printf '%s' "$test_prompt" |
                CODEX_WORKER_MODEL=test-model bash "$agent_dir/$entry" "${args[@]}" "$test_cwd" -)
        fi
        returned_id=$(printf '%s' "$response" | node --input-type=module -e '
            import assert from "node:assert/strict";
            import { text } from "node:stream/consumers";
            const reply = JSON.parse(await text(process.stdin));
            assert.deepEqual(reply, { session_id: process.env.test_id, reply: "回答\nOK" });
            console.log(reply.session_id);
        ')
    done
    for test_mode in truncated failure bad_exit; do
        if response=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>/dev/null); then
            echo "$entry unexpectedly succeeded in $test_mode" >&2
            exit 1
        fi
        [[ -z $response ]]
    done
    if [[ $entry == codex-worker ]]; then
        # A stopped run must still leave the session ID on stderr.
        test_mode=truncated
        errors=$(bash "$agent_dir/$entry" "$test_cwd" "$test_prompt" 2>&1 >/dev/null || true)
        [[ $errors == *"codex: session_id $test_id"* ]] || { echo 'codex-worker did not report the session ID early' >&2; exit 1; }
    fi
    printf 'PASS %s: first request, resume, incomplete reply, failed turn, nonzero exit\n' "$entry"
done
