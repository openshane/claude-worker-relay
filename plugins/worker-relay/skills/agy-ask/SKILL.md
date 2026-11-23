---
name: agy-ask
description: Ask Gemini through the local Antigravity CLI for a second opinion on code, a design or an earlier Gemini reply. Use when the user requests Gemini input or a follow-up to a Gemini worker session.
---

Use the requested workspace as the working directory, or the current project if none was specified. Send the user's question to the installed script with Bash. Use a single-quoted heredoc delimiter that does not occur in the question so that shell expressions and Markdown reach the worker literally.

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/agy-ask" "." - <<'WORKER_QUESTION'
Put the question here.
WORKER_QUESTION
```

For a follow-up, insert `--resume "<session_id>"` before the directory and use the same workspace. Read `reply` and retain `session_id` from the successful JSON output. Run in the foreground by default. If the user requests background work, set the Bash tool's `run_in_background` to true and read the result when the task finishes. On failure, report the actual CLI error.
