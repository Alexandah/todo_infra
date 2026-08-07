#!/bin/bash
# tmux-relayout.sh — standalone relayout trigger
# Invoked by tmux's pane-exited hook (set in dash_ensure_session).
# Must dispatch via dash_view_apply (not dash_relayout directly) so that a
# pane exiting while in zen mode re-picks and zooms the next zen candidate
# instead of silently falling through to (or freezing on) the grid view.
source "$HOME/.claude/hooks/tmux-helpers.sh"
dash_view_apply
