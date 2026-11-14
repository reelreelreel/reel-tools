#!/bin/bash
# usage: peak.sh out shot  (env passes through) -> prints peak RSS of godot
( /tmp/shoot.sh "$@" ) &
P=$!
peak=0
while kill -0 $P 2>/dev/null; do
  r=$(ps -C godot -o rss= | sort -n | tail -1); r=${r:-0}
  [ "$r" -gt "$peak" ] && peak=$r
  sleep 1
done
echo "peak RSS MB: $((peak/1024))"
