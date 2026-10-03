# Measurement build: solve one state and print the solution.
# The --iret figures and the budget check use this build.
# tools/build.sh measure STATE replaces the input string.

    .data
input:
    .string "54721631111111"

    .text
    .globl main
main:
    li   sp, 0x7ffffff0      # same as the GUI default; CLI starts with sp = 0
    la   a0, input
    jal  ra, solve_input     # a0 = length, path[] = moves
    jal  ra, print_path
    li   a7, 10              # exit
    ecall
