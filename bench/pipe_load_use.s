# Pipeline micro-benchmark A: a load whose result is used by the very next instruction.
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
    lbu  t4, 1(t1)
    bgeu t4, zero, next   # uses t4 right after the load: load-use hazard
next:
    addi s0, s0, -1
    bnez s0, loop
    li   a7, 10
    ecall
