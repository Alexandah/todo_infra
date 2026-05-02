#!/bin/bash
set -e
source bash_utils
timestamp=$(date '+%D %T' | tr '/' '-')
if [ -n "$1" ]; then
  logentry="$timestamp	$1"
else
  read -e -i "$timestamp	" logentry
fi
echo "# $logentry" >> "$(pathtothisfile)"
# LOG
