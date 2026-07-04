#!/bin/bash
set -e
source /home/erandalex/main/todo/.infra/bash_utils

MY_NAME=$(basename "$0")
taskdir=$(cd "$(dirname "$0")" && pwd)
SCRIPT_PATH=$(realpath "$0")

if [ "$MY_NAME" = "start_work_sess.do" ]; then
	date +%s > "$taskdir/.work_sess_start_time"
	mv "$SCRIPT_PATH" "$taskdir/stop_work_sess.do"
	echo "Session started."
else
	timestamp=$(date '+%D %T' | tr '/' '-')
	start_time=$(cat "$taskdir/.work_sess_start_time")
	now=$(date +%s)
	time_elapsed_s=$(( now - start_time ))
	time_elapsed_hr=$(echo "scale=2; $time_elapsed_s / 3600" | bc)

	# Update :time=* file
	time_file=$(find "$taskdir" -maxdepth 1 -name ':time=*' | head -n 1)
	if [ -n "$time_file" ]; then
		current_hours=$(basename "$time_file" | sed 's/:time=//; s/h$//')
		new_hours=$(echo "scale=2; $current_hours - $time_elapsed_hr" | bc)
		mv "$time_file" "$taskdir/:time=${new_hours}h"
		echo "Logged ${time_elapsed_hr}h. Remaining: ${new_hours}h"
	fi

	# Log entry
	read -e -i "$timestamp	${time_elapsed_hr}h worked	" logentry
	echo "# $logentry" >> "$SCRIPT_PATH"

	mv "$SCRIPT_PATH" "$taskdir/start_work_sess.do"
fi
# LOG
