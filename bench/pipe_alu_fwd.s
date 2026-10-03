# Pipeline micro-benchmark C: an ALU result used by the next instruction (EX-to-EX forwarding).
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
    add  t4, t1, zero
    lbu  t3, 0(t4)        # uses t4 right away
    addi s0, s0, -1
    bnez s0, loop
    li   a7, 10
    ecall
