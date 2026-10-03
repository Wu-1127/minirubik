#!/bin/sh
# Run the pipeline micro-benchmarks on RV32_5S.
# Usage: RIPES=/path/to/Ripes bench/pipe_bench.sh
: "${RIPES:?set RIPES to the Ripes binary}"
for f in bench/pipe_alu_fwd.s bench/pipe_branch.s bench/pipe_load_gap.s bench/pipe_load_use.s; do
  out=$("$RIPES" --mode cli --src "$f" -t asm --proc RV32_5S --iret --cycles)
  cyc=$(printf '%s\n' "$out" | grep -A1 '===== cycles' | tail -1)
  ret=$(printf '%s\n' "$out" | grep -A1 'instructions retired' | tail -1)
  echo "$f cycles $cyc iret $ret"
done
