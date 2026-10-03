#!/bin/sh
# Assemble one Ripes source file from the pieces.
# Ripes (v2.2.6-106) has no .if directive, so builds are selected here
# by choosing which main file to concatenate.
#
# Usage: tools/build.sh MODE [STATE]
#   MODE  measure | tests
#   STATE optional 14-digit state for the measure build
# Output: asm/build/ida_MODE.s (path printed on stdout)
set -e
mode=$1
state=$2
mkdir -p asm/build
out=asm/build/ida_$mode.s
{ cat asm/main_$mode.s; echo; cat asm/solver.s; echo; cat asm/tables.s; } > "$out.tmp"
if [ -n "$state" ]; then
  sed "s/\.string \"[0-9]*\"/.string \"$state\"/" "$out.tmp" > "$out"
  rm "$out.tmp"
else
  mv "$out.tmp" "$out"
fi
echo "$out"
