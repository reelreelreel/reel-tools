#!/bin/bash
# usage: shoot.sh out_dir shots [extra args]
cd /home/claude/reel-tools/godot
mkdir -p $1
REEL_NOBAKE=1 REEL_LOWMEM=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 1700 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --resolution 1280x720 -- --screenshot=$1/ --shots=$2 --frames=25 "${@:3}" > /tmp/run.log 2>&1
grep -E "screenshot:|SCRIPT|Killed" /tmp/run.log
