#!/usr/bin/env bash
# Smoke test: short all-bot autotest runs that must finish without a crash,
# a script error, a stalled pour or a timeout. Used by CI on every PR
# (.github/workflows/smoke.yml) and runnable by any session:
#   GODOT=/path/to/godot tools/ci/smoke.sh [run-name ...]
# Exit 0 = all runs passed. Logs go to $SMOKE_LOGS (default /tmp/smoke-logs).
set -u
GODOT="${GODOT:-godot}"
LOGS="${SMOKE_LOGS:-/tmp/smoke-logs}"
LIMIT="${SMOKE_LIMIT:-900}"          # seconds per run
cd "$(dirname "$0")/../.."
mkdir -p "$LOGS"

# name | user args after `--`
RUNS=(
  "riverlight_top|--autotest --nophones --startlevel=11"
  "tutorial|--autotest --nophones --tutorial"
  "spire_top|--autotest --nophones --site=spire --startlevel=34"
)
want=("$@")

# (fresh import first, so every run starts from the same cache)
"$GODOT" --headless --path . --import > "$LOGS/import.log" 2>&1 || true

fail=0
summary=""
for r in "${RUNS[@]}"; do
  name="${r%%|*}"; args="${r#*|}"
  if [ ${#want[@]} -gt 0 ] && [[ ! " ${want[*]} " =~ " $name " ]]; then continue; fi
  log="$LOGS/$name.log"
  start=$(date +%s)
  # (a throwaway user folder, so saved progress and settings never leak into a test)
  home=$(mktemp -d)
  HOME="$home" XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    timeout "$LIMIT" "$GODOT" --headless --path . --fixed-fps 60 -- $args > "$log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  # (Godot's own leak report when the game quits is noise, not a bug in the game)
  errs=$(grep -E 'SCRIPT ERROR|^ERROR:|Parse Error|Invalid call|Invalid access' "$log" | grep -vcE 'at exit|leaked|PagedAllocator')
  topped=$(grep -c 'TOPPED OUT' "$log")
  status=PASS
  why=""
  if [ $code -eq 124 ]; then status=FAIL; why="timed out after ${LIMIT}s"
  elif [ $code -ne 0 ]; then status=FAIL; why="exit code $code"
  elif [ "$errs" -gt 0 ]; then status=FAIL; why="$errs error line(s)"
  elif [ "$topped" -eq 0 ]; then status=FAIL; why="never topped out"
  fi
  [ $status = FAIL ] && fail=1
  line="$status  $name  (${secs}s) $why"
  echo "$line"
  summary+="$line"$'\n'
  if [ $status = FAIL ]; then
    echo "---- first errors in $name ----"
    grep -nE -A3 'SCRIPT ERROR|^ERROR:|Parse Error|Invalid call|Invalid access|stuck in phase|timed out' "$log" | grep -vE 'at exit|leaked|PagedAllocator' | head -40
    echo "---- last lines of $name ----"
    tail -25 "$log"
  fi
  rm -rf "$home"
done
printf '%s' "$summary" > "$LOGS/summary.txt"
exit $fail
