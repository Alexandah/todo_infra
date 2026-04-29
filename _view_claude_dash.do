#!/bin/bash
if [ -n "$TMUX" ]; then
    echo "Error: cannot attach to claude-dash from inside tmux. Run from a non-tmux terminal." >&2
	sleep 1
    exit 1
fi
source "$HOME/.claude/hooks/tmux-helpers.sh"
dash_ensure_session
exec tmux attach-session -t claude-dash
