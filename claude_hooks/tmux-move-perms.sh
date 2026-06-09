#!/bin/bash
# Hook: PermissionRequest
# Moves the current pane to the perms column.
INPUT=$(cat)
[ -z "$CLAUDE_TMUX_MANAGED" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0
source "$(dirname "$0")/tmux-helpers.sh"
dash_move_task "$TMUX_PANE" perms
