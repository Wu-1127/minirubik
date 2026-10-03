#!/bin/sh
# Compare the assembly solver with gcc -O2 -march=rv32i on the same C algorithm.
# Usage: RIPES=/path/to/Ripes RVGCC=/path/to/toolchain/bin tools/gcc_compare.sh [STATE ...]
# Default states: worst case, the reported state, solved.
: "${RIPES:?set RIPES to the Ripes binary}"
: "${RVGCC:?set RVGCC to the bin directory of riscv-none-elf-gcc}"
set -e
[ $# -eq 0 ] && set -- 54721631111111 21345671111111 12345671111111
CFLAGS="-O2 -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -T gcc/link.ld"
mkdir -p gcc/build

"$RVGCC/riscv-none-elf-gcc" $CFLAGS -o gcc/build/rv_ida.elf gcc/rv_ida.c -lgcc
"$RVGCC/riscv-none-elf-as" -march=rv32i -mabi=ilp32 -o gcc/build/asm.o "$(tools/build.sh measure)"

echo "== .text bytes"
printf "gcc -O2   %s\n" "$("$RVGCC/riscv-none-elf-size" -A gcc/build/rv_ida.elf | awk '$1==".text"{print $2}')"
printf "assembly  %s\n" "$("$RVGCC/riscv-none-elf-size" -A gcc/build/asm.o | awk '$1==".text"{print $2}')"

echo "== --iret on RV32_ISS (state, gcc, assembly)"
for s in "$@"; do
  "$RVGCC/riscv-none-elf-gcc" $CFLAGS -DINPUT="\"$s\"" -o "gcc/build/rv_$s.elf" gcc/rv_ida.c -lgcc
  g=$("$RIPES" --mode cli --src "gcc/build/rv_$s.elf" -t elf --proc RV32_ISS --iret | grep -A1 'instructions retired' | tail -1)
  a=$("$RIPES" --mode cli --src "$(tools/build.sh measure "$s")" -t asm --proc RV32_ISS --iret | grep -A1 'instructions retired' | tail -1)
  echo "$s $g $a"
done
