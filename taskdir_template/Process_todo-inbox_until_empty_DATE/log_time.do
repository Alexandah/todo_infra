#!/bin/bash
set -e
source /home/erandalex/main/todo/.infra/bash_utils

taskdir=$(cd "$(dirname "$0")" && pwd)

# Accounts for --gap=1 not supported by fzf 0.54.2 on AMD machine
if cat /etc/os-release 2>/dev/null | grep -q 'NAME="Rocky Linux"'; then
    fzf_gap_arg=''
else
    fzf_gap_arg='--gap=1'
fi

# Find current :time=* file
time_file=$(find "$taskdir" -maxdepth 1 -name ':time=*' | head -n 1)
if [ -z "$time_file" ]; then
    echo "ERROR: No :time=* file found in $taskdir" >&2
    exit 1
fi

current_hours=$(basename "$time_file" | sed 's/:time=//; s/h$//')

# Preserve original estimate if not already saved (hidden from plain ls)
orig_file="$taskdir/.time_orig"
if [ ! -f "$orig_file" ]; then
    echo "$current_hours" > "$orig_file"
fi

time_suggestions=$(
    echo "0.03       2m"
    echo "0.08       5m"
    echo "0.11       7m"
    echo "0.17       10m"
    echo "0.25       15m"
    echo "0.33       20m"
    echo "0.41       25m"
    echo "0.50       30m"
    echo "0.75       45m"
    echo "1          1h"
    echo "1.25       1h 15m"
    echo "1.50       1h 30m"
    echo "1.75       1h 45m"
    echo "2          2h"
)

run 'echo "$time_suggestions" | fzf --prompt="HOURS_WORKED >" --header="HOURS      AKA" --print-query $fzf_gap_arg'
exit_code=$?
if [ "$exit_code" -gt "1" ]; then
    echo "ERROR: fzf had unexpected exit code: $exit_code" >&2
    exit "$exit_code"
fi

# exit 0: item selected from list; exit 1: custom value typed (no list match)
if [ "$exit_code" -eq "0" ]; then
    hours_worked=$(echo "$STDOUT" | tail -n 1 | awk '{print $1}')
else
    hours_worked=$(echo "$STDOUT" | head -n 1 | awk '{print $1}')
fi

if [ -z "$hours_worked" ]; then
    echo "ERROR: No time entered." >&2
    exit 1
fi

# Calculate remaining hours (supports negative when time exceeds estimate)
# bc used instead of dc: dc uses _ for negative literals, so dc misparses filenames like :time=-.18h
new_hours=$(echo "scale=2; $current_hours - $hours_worked" | bc)

# Rename :time=* file to reflect remaining time
mv "$time_file" "$taskdir/:time=${new_hours}h"

echo "Logged ${hours_worked}h. Remaining: ${new_hours}h"
