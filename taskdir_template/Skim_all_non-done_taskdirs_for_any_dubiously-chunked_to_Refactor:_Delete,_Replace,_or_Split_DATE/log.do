#!/bin/bash
set -e
source /home/aledavis/main/doc/todo/.infra/bash_utils
timestamp=$(date '+%D %T' | tr '/' '-')
read -e -i "$timestamp	" logentry
echo "# $logentry" >> "$(pathtothisfile)"
# LOG
