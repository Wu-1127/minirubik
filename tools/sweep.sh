#!/bin/sh
# Run the assembly solver in Ripes on every state of a list and compare
# its output with the C solver.
# Usage: RIPES=/path/to/Ripes tools/sweep.sh LIST OUT
# Output: state distance nodes generated iret OK|MISMATCH
: "${RIPES:?set RIPES to the Ripes binary}"
tmp=$(mktemp -d)
while read -r state d n g sol; do
  sed "s/\.string \"[0-9]*\"/.string \"$state\"/" asm/ida_code.s > "$tmp/code.s"
  { cat "$tmp/code.s"; echo; cat asm/tables.s; } > "$tmp/ida.s"
  "$RIPES" --mode cli --src "$tmp/ida.s" -t asm --proc RV32_ISS --iret > "$tmp/out.txt" 2>&1
  got=$(head -1 "$tmp/out.txt" | tr ' ' ',')
  iret=$(grep -A1 'instructions retired' "$tmp/out.txt" | tail -1)
  if [ "$got" = "$sol" ]; then ok=OK; else ok=MISMATCH; fi
  echo "$state $d $n $g $iret $ok"
done < "$1" > "$2"
rm -rf "$tmp"