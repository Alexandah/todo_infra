#!/bin/bash
# tmux-helpers.sh — dashboard functions for Claude tmux pane management
# Sourced by all tmux hook scripts and taskdir_tmux_launch.
#
# Architecture: single tmux session "claude-dash" with one window "dash"
# containing three columns of panes (running, perms, done).
# Column membership tracked via pane user option @column.

CLAUDE_DASH_SESSION="claude-dash"
CLAUDE_DASH_WINDOW="dash"
CLAUDE_DASH_LOCKFILE="/tmp/claude-dash-relayout.lock"

# --- dash_ensure_session ---
# Create the claude-dash session with 3 header panes if it doesn't exist.
dash_ensure_session() {
    tmux has-session -t "$CLAUDE_DASH_SESSION" 2>/dev/null && return 0

    # Create session with RUNNING header
    tmux new-session -d -s "$CLAUDE_DASH_SESSION" -n "$CLAUDE_DASH_WINDOW" \
        "printf '\\033[7m RUNNING \\033[0m\\n'; sleep infinity"
    local p1
    p1=$(tmux list-panes -t "$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW" -F '#{pane_id}')
    tmux set-option -p -t "$p1" @column running
    tmux set-option -p -t "$p1" @header 1
    tmux set-option -p -t "$p1" remain-on-exit on

    # Split horizontally for PERMS header
    local p2
    p2=$(tmux split-window -h -t "$p1" -d -P -F '#{pane_id}' \
        "printf '\\033[7m PERMS \\033[0m\\n'; sleep infinity")
    tmux set-option -p -t "$p2" @column perms
    tmux set-option -p -t "$p2" @header 1
    tmux set-option -p -t "$p2" remain-on-exit on

    # Split horizontally for DONE header
    local p3
    p3=$(tmux split-window -h -t "$p2" -d -P -F '#{pane_id}' \
        "printf '\\033[7m DONE \\033[0m\\n'; sleep infinity")
    tmux set-option -p -t "$p3" @column done
    tmux set-option -p -t "$p3" @header 1
    tmux set-option -p -t "$p3" remain-on-exit on

    # Equalize column widths
    tmux select-layout -t "$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW" even-horizontal

    # Register pane-exited hook for auto-relayout
    tmux set-hook -t "$CLAUDE_DASH_SESSION" pane-exited \
        "run-shell 'bash $HOME/.claude/hooks/tmux-relayout.sh'"

    # Re-equalize on terminal resize too
    tmux set-hook -t "$CLAUDE_DASH_SESSION" client-resized \
        "run-shell 'bash $HOME/.claude/hooks/tmux-relayout.sh'"
}

# --- dash_relayout ---
# Enforce three-column sizing after any structural change.
# Uses flock to serialize concurrent invocations from multiple hooks.
dash_relayout() {
    # Acquire lock in a block so FD 9 closes (and lock releases) on return.
    # Without the block, `exec 9>FILE` would leak FD 9 into the calling shell;
    # taskdir_tmux_launch then `exec tmux attach`, inheriting the held lock,
    # which deadlocks every subsequent hook-driven relayout.
    {
    flock 9

    local target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"

    # Bail if session doesn't exist
    tmux has-session -t "$CLAUDE_DASH_SESSION" 2>/dev/null || return 0

    # Skip relayout while user is zoomed — resize-pane would unzoom.
    # dash_move_task saves/restores zoom around intentional moves.
    local zoomed
    zoomed=$(tmux display-message -t "$target" -p '#{window_zoomed_flag}' 2>/dev/null)
    [ "$zoomed" = "1" ] && return 0

    local win_w
    win_w=$(tmux display-message -t "$target" -p '#{window_width}')
    local col_w=$(( (win_w - 2) / 3 ))  # minus 2 vertical separators

    local header task_count
    for col in running perms done; do
        header=$(tmux list-panes -t "$target" -F '#{pane_id} #{@column} #{@header}' \
            | awk -v c="$col" '$2==c && $3=="1" {print $1}')
        [ -z "$header" ] && continue

        # Set column width via header pane (propagates to all panes in column)
        tmux resize-pane -t "$header" -x "$col_w" 2>/dev/null

        # Shrink header to 2 rows only if there are task panes below it
        task_count=$(tmux list-panes -t "$target" -F '#{@column} #{@header}' \
            | awk -v c="$col" '$1==c && $2!="1"' | wc -l)
        if [ "$task_count" -gt 0 ]; then
            tmux resize-pane -t "$header" -y 2 2>/dev/null

            # Equalize task pane heights within this column.
            local win_h task_h task_panes count total
            win_h=$(tmux display-message -t "$target" -p '#{window_height}')
            task_h=$(( (win_h - 2 - (task_count - 1)) / task_count ))
            [ "$task_h" -lt 1 ] && task_h=1

            # Order task panes top-to-bottom by pane_top so resize is deterministic.
            # Use '|' separator since @header may be empty for task panes; default
            # whitespace splitting would collapse the empty field and shift pane_top.
            task_panes=$(tmux list-panes -t "$target" \
                -F '#{pane_id}|#{@column}|#{@header}|#{pane_top}' \
                | awk -F'|' -v c="$col" '$2==c && $3!="1" {print $4, $1}' \
                | sort -n | awk '{print $2}')

            # Resize all but the last; tmux absorbs the remainder into the final sibling.
            # Use while-read so it works in both bash (sourced by hook scripts) and
            # zsh (sourced for ad-hoc testing) — `for p in $var` only word-splits in bash.
            count=0
            total="$task_count"
            while IFS= read -r p; do
                [ -z "$p" ] && continue
                count=$((count + 1))
                [ "$count" -eq "$total" ] && break
                tmux resize-pane -t "$p" -y "$task_h" 2>/dev/null
            done <<< "$task_panes"
        fi
    done
    } 9>"$CLAUDE_DASH_LOCKFILE"
}

# --- dash_add_task ---
# Add a new task pane to a column.
# Usage: dash_add_task <column> <task_name> <command>
# Prints the new pane ID to stdout.
dash_add_task() {
    local column="$1"
    local task_name="$2"
    local cmd="$3"
    local target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"

    dash_ensure_session

    # Find the last pane in this column (by pane index) to split below it
    local last_pane
    last_pane=$(tmux list-panes -t "$target" -F '#{pane_id} #{@column} #{pane_index}' \
        | awk -v c="$column" '$2==c {print $3, $1}' | sort -n | tail -1 | awk '{print $2}')

    # Fallback: if no pane in column, find the header
    if [ -z "$last_pane" ]; then
        last_pane=$(tmux list-panes -t "$target" -F '#{pane_id} #{@column} #{@header}' \
            | awk -v c="$column" '$2==c && $3=="1" {print $1}')
    fi

    [ -z "$last_pane" ] && return 1

    # Split below the last pane in the column
    local new_pane
    new_pane=$(tmux split-window -v -t "$last_pane" -d -P -F '#{pane_id}' "$cmd")

    # Set metadata
    tmux set-option -p -t "$new_pane" @column "$column"
    tmux set-option -p -t "$new_pane" @task_name "$task_name"

    dash_relayout

    echo "$new_pane"
}

# --- dash_move_task ---
# Move a task pane to a different column.
# Usage: dash_move_task <pane_id> <new_column>
dash_move_task() {
    local pane_id="$1"
    local new_column="$2"
    local target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"

    # Check if already in target column (no-op)
    local current_col
    current_col=$(tmux display-message -t "$pane_id" -p '#{@column}' 2>/dev/null)
    [ "$current_col" = "$new_column" ] && return 0

    # Find the header pane of the target column
    local target_header
    target_header=$(tmux list-panes -t "$target" -F '#{pane_id} #{@column} #{@header}' \
        | awk -v c="$new_column" '$2==c && $3=="1" {print $1}')
    [ -z "$target_header" ] && return 1

    # Save focus and zoom before join-pane clears both
    local active_pane zoomed_pane
    active_pane=$(tmux display-message -t "$target" -p '#{pane_id}' 2>/dev/null)
    zoomed_pane=$(tmux list-panes -t "$target" -F '#{pane_id} #{pane_active} #{window_zoomed_flag}' \
        | awk '$2==1 && $3==1 {print $1}')

    # Expand header to make room for the join (relayout will re-shrink)
    tmux resize-pane -t "$target_header" -y 10 2>/dev/null

    # Move pane to below the target column's header (-d: don't steal focus)
    tmux join-pane -v -d -t "$target_header" -s "$pane_id"

    # Update column metadata
    tmux set-option -p -t "$pane_id" @column "$new_column"

    dash_relayout

    # Restore focus and zoom (join-pane + relayout clear both)
    [ -n "$active_pane" ] && tmux select-pane -t "$active_pane" 2>/dev/null
    [ -n "$zoomed_pane" ] && tmux resize-pane -Z -t "$zoomed_pane" 2>/dev/null
    return 0
}
