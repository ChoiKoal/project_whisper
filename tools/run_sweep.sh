#!/bin/bash
# Resumable harness sweep: records green harnesses in game/.sweep_done so a
# restarted agent skips them. Delete .sweep_done to force a full re-run.
# Usage: tools/run_sweep.sh   (run from repo root; exits nonzero on first failure)
set -u
GODOT=/workspace/group/tools/Godot_v4.5-stable_linux.arm64
cd "$(dirname "$0")/../game" || exit 2
DONE_FILE=.sweep_done
touch "$DONE_FILE"
SKIP_RE='home_overview_render'   # render tools, not harnesses
fails=0
for scene in scenes/dev/*.tscn; do
  name=$(basename "$scene" .tscn)
  [[ "$name" =~ $SKIP_RE ]] && continue
  grep -qx "$name" "$DONE_FILE" && { echo "SKIP(green) $name"; continue; }
  echo "RUN $name"
  timeout 300 "$GODOT" --headless "res://$scene" > "/tmp/sweep_$name.log" 2>&1
  code=$?
  if [ "$code" -eq 0 ]; then
    echo "$name" >> "$DONE_FILE"
    echo "PASS $name"
  else
    echo "FAIL $name (exit $code) — log: /tmp/sweep_$name.log"
    fails=$((fails+1))
    exit 1   # stop at first failure so the agent fixes it, then re-runs
  fi
done
echo "SWEEP COMPLETE: all green ($(wc -l < "$DONE_FILE") harnesses)"
exit 0
