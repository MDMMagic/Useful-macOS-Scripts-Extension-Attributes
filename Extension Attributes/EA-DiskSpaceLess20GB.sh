#!/bin/bash
#
# Author - Dan@MDMmagic.au
# Date - 1st May 2026
# Version 1.0
#

# Get free space in GB (integer)
freeSpaceGB=$(df -g / | tail -1 | awk '{print $4}')

echo "Free space: $freeSpaceGB GB"

if [[ "$freeSpaceGB" -le 20 ]]; then
    echo "<result>Less than 20GB left</result>"
else
    echo "<result>OK</result>"
fi

exit 0