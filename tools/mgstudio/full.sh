#!/bin/bash
# full-quality renders, one after another (2 CPUs)
cd /home/claude/mgstudio
for job in "$@"; do s=${job%%:*}; k=${job##*:}; python3 $s.py $k > /dev/null 2>&1 && echo "OK $job" || echo "FAIL $job"; done
echo ALLDONE
