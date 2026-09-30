    .text
    .globl main
main:
    lui  t0, 0x18      # t0 = 0x18 << 12
    addi t0, t0, 1696  # t0 = t0 + 1696 = 100000
loop:
    addi t0, t0, -1    # t0 = t0 - 1
    bne  t0, x0, loop  # if (t0 != 0) then loop 
    addi a7, x0, 10    # a7 = 10  
    ecall
