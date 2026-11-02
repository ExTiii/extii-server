#!/bin/bash
# full quality: python3 render.py <module> ... ; final pngs land in final/
cd /home/claude/icons
for m in "$@"; do python3 render.py $m >> hq/$m.log 2>&1; echo "== $m finished" >> hq/$m.log; done
