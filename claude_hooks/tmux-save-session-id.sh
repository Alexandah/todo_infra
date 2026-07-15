#!/bin/bash
# Hook: UserPromptSubmit
# Writes .last_session_id to $PWD on first prompt so claude_task can resume.
INPUT=$(cat)
[ -z "$CLAUDE_TMUX_MANAGED" ] && exit 0
[ -n "$CLAUDE_ADHOC" ] && exit 0
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0
[ -f .last_session_id ] && [ "$(cat .last_session_id)" = "$SESSION_ID" ] && exit 0
echo "$SESSION_ID" > .last_session_id
