    .text
    .globl main
main:
    lui  t1, 0x10000     # t1 = 0x10000000 
    lui  t0, 0x18        # t0 = 0x18 << 12 = 98304
    addi t0, t0, 1696    # t0 = 98304 + 1696 = 100000
loop:
    sw   t0, 0(t1)       # mem[t1] = t0
    addi t1, t1, 4       # t1 = t1 + 4
    addi t0, t0, -1      # t0 = t0 - 1
    bne  t0, x0, loop    # if (t0 != 0) then loop
    addi a7, x0, 10      # a7 = 10 
    ecall
