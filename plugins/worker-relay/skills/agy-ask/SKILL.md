---
name: agy-ask
description: Ask Gemini through the local Antigravity CLI for a second opinion on code, a design or an earlier Gemini reply. Use when the user requests Gemini input or a follow-up to a Gemini worker session.
---

Use the requested workspace as the working directory, or the current project if none was specified. The script tells Gemini to leave files unchanged and to answer in fixed sections; write only the question itself.

- For an independent plan, give Gemini the user's own words and the background it needs, but not your draft or your preference, so that its view stays independent. Then check which of its points hold and merge them into one plan for the user.
- To review user-facing copy and interaction, add `--copy` as the first argument. Describe who the page is for, what the user should accomplish there, and the current copy and interaction. Before adopting a suggestion, confirm that it matches what the product actually does.

Gemini may invent details or make promises the product cannot keep, so verify its claims against the code before relying on them.

Send the question to the installed script with Bash. Use a single-quoted heredoc delimiter that does not occur in the question so that shell expressions and Markdown reach the worker literally.

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/agy-ask" "." - <<'WORKER_QUESTION'
Put the question here.
WORKER_QUESTION
```

For a follow-up, insert `--resume "<session_id>"` before the directory (after `--copy` when used) and use the same workspace. Read `reply` and retain `session_id` from the successful JSON output. Run in the foreground by default. If the user requests background work, set the Bash tool's `run_in_background` to true and read the result when the task finishes. On failure, report the actual CLI error.

Exit code 3 means Gemini changed files in the workspace even though it was told not to; the JSON reply is still on stdout and the changed paths are on stderr. Show the user those paths and leave reverting them to the user.
