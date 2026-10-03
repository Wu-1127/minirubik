# Pipeline micro-benchmark B: a load and its user separated by one independent instruction.
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
    addi t5, t5, 1        # independent
    bgeu t4, zero, next   # uses t4 two instructions after the load
next:
    addi s0, s0, -1
    bnez s0, loop
    li   a7, 10
    ecall
