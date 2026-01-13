#!/bin/bash
set -e
source bash_utils
timestamp=$(date '+%D %T' | tr '/' '-')
read -e -i "$timestamp	" logentry
echo "# $logentry" >> "$(pathtothisfile)"
# LOG
