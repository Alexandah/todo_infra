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
CLAUDE_DASH_PERMS_STACK="${CLAUDE_DASH_PERMS_STACK:-/tmp/claude-dash-perms.stack}"
CLAUDE_DASH_DONE_STACK="${CLAUDE_DASH_DONE_STACK:-/tmp/claude-dash-done.stack}"
CLAUDE_DASH_COLOR_STATE="${CLAUDE_DASH_COLOR_STATE:-/tmp/claude-dash-color.state}"
CLAUDE_DASH_COLOR_LOCKFILE="${CLAUDE_DASH_COLOR_LOCKFILE:-/tmp/claude-dash-color.lock}"
_DASH_COLORS=(red blue green yellow purple orange pink cyan)

# --- _dash_next_color ---
# Round-robin through _DASH_COLORS, persisting the last-used index across
# invocations in CLAUDE_DASH_COLOR_STATE (lock-guarded for concurrent launches).
_dash_next_color() {
    local idx
    {
        flock -x 9
        idx=$(cat "$CLAUDE_DASH_COLOR_STATE" 2>/dev/null)
        [ -z "$idx" ] && idx=-1
        idx=$(( (idx + 1) % ${#_DASH_COLORS[@]} ))
        echo "$idx" > "$CLAUDE_DASH_COLOR_STATE"
    } 9>"$CLAUDE_DASH_COLOR_LOCKFILE"
    echo "${_DASH_COLORS[$idx]}"
}

# --- _dash_stack_push ---
# Push pane_id onto a stack file (dedupe-then-append so it is the unique top).
# Usage: _dash_stack_push <stack_file> <pane_id>
_dash_stack_push() {
    local file="$1"
    local pane_id="$2"
    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXX")
    # Remove any existing entry for this pane_id, then append it as new top.
    if [ -f "$file" ]; then
        grep -Fxv "$pane_id" "$file" > "$tmp" || true
    fi
    printf '%s\n' "$pane_id" >> "$tmp"
    mv -f "$tmp" "$file"
}

# --- _dash_stack_remove ---
# Remove all lines equal to pane_id from a stack file.
# Usage: _dash_stack_remove <stack_file> <pane_id>
_dash_stack_remove() {
    local file="$1"
    local pane_id="$2"
    [ -f "$file" ] || return 0
    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXX")
    grep -Fxv "$pane_id" "$file" > "$tmp" || true
    mv -f "$tmp" "$file"
}

# --- _dash_stack_pop ---
# Print the top (last line) of the stack and remove it.
# Skips/discards pane ids that are no longer live in the dash session.
# Prints nothing if the stack is empty or all entries are stale.
# Usage: _dash_stack_pop <stack_file>
_dash_stack_pop() {
    local file="$1"
    [ -f "$file" ] || return 0
    local live_panes pane_id tmp
    live_panes=$(tmux list-panes -s -t "$CLAUDE_DASH_SESSION" -F '#{pane_id}' 2>/dev/null || true)
    while true; do
        [ -f "$file" ] || break
        # Read last line
        pane_id=$(tail -n 1 "$file" 2>/dev/null)
        [ -z "$pane_id" ] && break
        # Remove it from the stack unconditionally
        tmp=$(mktemp "${file}.tmp.XXXXXX")
        head -n -1 "$file" > "$tmp" 2>/dev/null || true
        mv -f "$tmp" "$file"
        # Check liveness using exact match
        if printf '%s\n' "$live_panes" | grep -Fxq "$pane_id"; then
            printf '%s\n' "$pane_id"
            return 0
        fi
        # Pane is stale — continue to next candidate
    done
}

# --- _dash_stacks_update ---
# Update PERMS and DONE stacks when a pane changes column.
# Usage: _dash_stacks_update <pane_id> <newcol>
_dash_stacks_update() {
    local pane_id="$1"
    local newcol="$2"
    case "$newcol" in
        perms)
            _dash_stack_remove "$CLAUDE_DASH_DONE_STACK"  "$pane_id"
            _dash_stack_push   "$CLAUDE_DASH_PERMS_STACK" "$pane_id"
            ;;
        done)
            _dash_stack_remove "$CLAUDE_DASH_PERMS_STACK" "$pane_id"
            _dash_stack_push   "$CLAUDE_DASH_DONE_STACK"  "$pane_id"
            ;;
        *)
            _dash_stack_remove "$CLAUDE_DASH_PERMS_STACK" "$pane_id"
            _dash_stack_remove "$CLAUDE_DASH_DONE_STACK"  "$pane_id"
            ;;
    esac
}

# --- _dash_zen_seed_stacks ---
# Self-healing: on Zen enter, scan all live panes and append any perms/done
# pane that is missing from its respective stack file. Skips headers and
# placeholders. Preserves existing stack order (checks membership before push).
# Must be called BEFORE dash_zen_render (so no relayout lock is held).
# Usage: _dash_zen_seed_stacks
_dash_zen_seed_stacks() {
    local pane_list
    pane_list=$(tmux list-panes -s -t "$CLAUDE_DASH_SESSION" \
        -F '#{pane_id} #{@column} #{@header} #{@zen_placeholder}' 2>/dev/null || true)

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local id col hdr ph
        id=$(printf '%s' "$line" | awk '{print $1}')
        col=$(printf '%s' "$line" | awk '{print $2}')
        hdr=$(printf '%s' "$line" | awk '{print $3}')
        ph=$(printf '%s' "$line" | awk '{print $4}')

        # Skip header panes and placeholder panes
        [ "$hdr" = "1" ] && continue
        [ "$ph"  = "1" ] && continue

        case "$col" in
            perms)
                # Only append if not already present (preserve existing order)
                if ! grep -Fxq "$id" "$CLAUDE_DASH_PERMS_STACK" 2>/dev/null; then
                    _dash_stack_push "$CLAUDE_DASH_PERMS_STACK" "$id"
                fi
                ;;
            done)
                if ! grep -Fxq "$id" "$CLAUDE_DASH_DONE_STACK" 2>/dev/null; then
                    _dash_stack_push "$CLAUDE_DASH_DONE_STACK" "$id"
                fi
                ;;
        esac
    done <<< "$pane_list"
}

# --- _dash_zen_valid ---
# Returns 0 iff pane_id is non-empty, live, in perms or done column,
# is NOT a header pane (@header == 1), and does NOT have @zen_placeholder == 1.
# Usage: _dash_zen_valid <pane_id>
_dash_zen_valid() {
    local pane_id="$1"
    [ -z "$pane_id" ] && return 1
    # Check liveness
    tmux list-panes -s -t "$CLAUDE_DASH_SESSION" -F '#{pane_id}' 2>/dev/null \
        | grep -Fxq "$pane_id" || return 1
    # Check column
    local col
    col=$(tmux show-options -p -t "$pane_id" -v @column 2>/dev/null)
    case "$col" in
        perms|done) ;;
        *) return 1 ;;
    esac
    # Reject header panes
    local hdr
    hdr=$(tmux show-options -p -t "$pane_id" -v @header 2>/dev/null)
    [ "$hdr" = "1" ] && return 1
    # Reject placeholder panes
    local placeholder
    placeholder=$(tmux show-options -p -t "$pane_id" -v @zen_placeholder 2>/dev/null)
    [ "$placeholder" = "1" ] && return 1
    return 0
}

# --- _dash_zen_pick ---
# Echo the pane id that should become the zen Main.
# Priority: top of PERMS stack -> top of DONE stack -> placeholder pane.
_dash_zen_pick() {
    local pane_id
    pane_id=$(_dash_stack_pop "$CLAUDE_DASH_PERMS_STACK")
    if [ -n "$pane_id" ]; then
        printf '%s\n' "$pane_id"
        return 0
    fi
    pane_id=$(_dash_stack_pop "$CLAUDE_DASH_DONE_STACK")
    if [ -n "$pane_id" ]; then
        printf '%s\n' "$pane_id"
        return 0
    fi
    # Fall back to the session-registered placeholder pane
    tmux show-options -t "$CLAUDE_DASH_SESSION" -v @zen_placeholder_pane 2>/dev/null || true
}

# --- dash_zen_render ---
# Zoom the current zen Main pane. Selects a new Main if the current one is invalid.
# Serialized with the same flock pattern as dash_relayout.
dash_zen_render() {
    {
    flock 9

    tmux has-session -t "$CLAUDE_DASH_SESSION" 2>/dev/null || return 0

    local target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"
    local cur
    cur=$(tmux show-options -t "$CLAUDE_DASH_SESSION" -v @zen_main 2>/dev/null || true)

    if ! _dash_zen_valid "$cur"; then
        cur=$(_dash_zen_pick)
        if [ -n "$cur" ]; then
            tmux set-option -t "$CLAUDE_DASH_SESSION" @zen_main "$cur"
        else
            tmux set-option -u -t "$CLAUDE_DASH_SESSION" @zen_main 2>/dev/null || true
        fi
    fi

    [ -z "$cur" ] && return 0

    # Unzoom first if already zoomed (so select-pane + re-zoom lands on the right pane)
    local zoomed
    zoomed=$(tmux display-message -t "$target" -p '#{window_zoomed_flag}' 2>/dev/null)
    [ "$zoomed" = "1" ] && tmux resize-pane -Z -t "$target" 2>/dev/null

    tmux select-pane -t "$cur" 2>/dev/null
    tmux resize-pane -Z -t "$cur" 2>/dev/null

    } 9>"$CLAUDE_DASH_LOCKFILE"
}

# --- dash_view_apply ---
# Dispatch to dash_relayout (normal view) or dash_zen_render (zen view)
# based on the @view session option (default: normal).
dash_view_apply() {
    local view
    view=$(tmux show-options -t "$CLAUDE_DASH_SESSION" -v @view 2>/dev/null || true)
    if [ "$view" = "zen" ]; then
        dash_zen_render
    else
        dash_relayout
    fi
}

# --- dash_ensure_session ---
# Create the claude-dash session with 3 header panes if it doesn't exist.
# Render each pane's @task_name on its border. Idempotent, and applied on the
# already-exists path too so a session created before this option existed gets
# upgraded in place. Header panes print their own inverse-video label, so their
# border is left blank rather than duplicating it.
_dash_borders() {
    local target="$CLAUDE_DASH_SESSION:$CLAUDE_DASH_WINDOW"
    tmux set-option -w -t "$target" pane-border-status top 2>/dev/null || true
    tmux set-option -w -t "$target" pane-border-format ' #{?@header,,#{@task_name}} ' 2>/dev/null || true
}

dash_ensure_session() {
    tmux has-session -t "$CLAUDE_DASH_SESSION" 2>/dev/null && { _dash_borders; return 0; }

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

    _dash_borders
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

    # Round-robin session coloring: inject `/color <next>` once the new
    # pane's Claude instance has booted enough to read its input loop.
    # Skipped for DASH_NO_COLOR panes: these run a plain TUI (fzf/lf/hmm), not
    # Claude, so the send-keys would be typed straight into whatever prompt is
    # on screen -- e.g. into the wizard's first fzf query, then Enter-submitted.
    if [ -z "${DASH_NO_COLOR:-}" ]; then
        local color
        color=$(_dash_next_color)
        ( sleep 2; tmux send-keys -t "$new_pane" "/color $color" Enter ) &
        disown 2>/dev/null || true
    fi

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

    # Update column metadata (ts lets guarded movers tell a fresh transition
    # from a stale one, e.g. tmux-move-running-if-stale.sh)
    tmux set-option -p -t "$pane_id" @column "$new_column"
    tmux set-option -p -t "$pane_id" @column_ts "$(date +%s%3N)"

    # Update zen stacks then dispatch to the active view renderer
    _dash_stacks_update "$pane_id" "$new_column"
    dash_view_apply

    # Restore focus and zoom (join-pane + relayout clear both).
    # In zen mode, dash_zen_render already set the correct focus+zoom; restoring
    # here would toggle-unzoom the window, so skip the block entirely.
    local _cur_view
    _cur_view=$(tmux show-options -t "$CLAUDE_DASH_SESSION" -v @view 2>/dev/null || true)
    if [ "$_cur_view" != "zen" ]; then
        [ -n "$active_pane" ] && tmux select-pane -t "$active_pane" 2>/dev/null
        [ -n "$zoomed_pane" ] && tmux resize-pane -Z -t "$zoomed_pane" 2>/dev/null
    fi
    return 0
}
