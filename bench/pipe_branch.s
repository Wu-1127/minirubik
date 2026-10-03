# Pipeline micro-benchmark D: a branch that is not taken, then the taken loop branch.
# 1000 iterations; compare --cycles with --iret on RV32_5S.
    .data
v:
    .byte 3, 5
    .text
    .globl main
main:
    la   t1, v
    li   s0, 1000
loop:
    bltu s0, zero, loop   # never taken
    addi s0, s0, -1
    bnez s0, loop
    li   a7, 10
    ecall
