    .data
halves:
    .half 1234, 5039
bytes:
    .byte 7, 6

    .text
    .globl main
main:
    la   t0, halves      # t0 = address of halves
    lhu  a0, 2(t0)       # second halfword, expect 5039
    li   a7, 1           # print integer
    ecall

    li   a0, 32          # space character
    li   a7, 11          # print character
    ecall

    la   t0, bytes       # t0 = address of bytes
    lbu  a0, 1(t0)       # second byte, expect 6
    li   a7, 1
    ecall

    li   a7, 10          # exit
    ecall
