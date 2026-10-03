#!/bin/sh
# Run the measurement build in Ripes on every state of a list and compare
# its output with the C solver.
# Usage: RIPES=/path/to/Ripes tools/sweep.sh LIST OUT
# LIST lines: state distance nodes generated solution(comma-separated)
# OUT lines:  state distance nodes generated iret OK|MISMATCH
: "${RIPES:?set RIPES to the Ripes binary}"
tmp=$(mktemp -d)
while read -r state d n g sol; do
  src=$(tools/build.sh measure "$state")
  "$RIPES" --mode cli --src "$src" -t asm --proc RV32_ISS --iret > "$tmp/out.txt" 2>&1
  got=$(head -1 "$tmp/out.txt" | tr ' ' ',')
  iret=$(grep -A1 'instructions retired' "$tmp/out.txt" | tail -1)
  if [ "$got" = "$sol" ]; then ok=OK; else ok=MISMATCH; fi
  echo "$state $d $n $g $iret $ok"
done < "$1" > "$2"
rm -rf "$tmp"
