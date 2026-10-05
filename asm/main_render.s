# Render build (Ripes GUI with a 35 x 25 LED matrix): show the scrambled cube,
# solve it, then apply the solver's moves one at a time and redraw the cube
# after every move. The animation is driven by path[], the solver's output.

    .data
input:
    .string "21345671111111"
    .align 2

    .text
    .globl main
main:
    li   sp, 0x7ffffff0      # same as the GUI default; CLI starts with sp = 0
    la   a0, input
    jal  ra, parse_cube
    jal  ra, show_frame      # the scrambled state

    la   a0, input
    jal  ra, solve_input     # a0 = length, path[] = moves
    mv   s0, a0              # s0 = number of moves
    li   s1, 0               # s1 = i
animate:
    beq  s1, s0, animate_done
    la   t0, path
    add  t0, t0, s1
    lbu  a0, 0(t0)           # move path[i]
    jal  ra, apply_move
    jal  ra, show_frame
    addi s1, s1, 1
    j    animate
animate_done:
    mv   a0, s0
    jal  ra, print_path
    li   a7, 10              # exit
    ecall

# show_frame: draw the cube, optionally dump it (CLI check), then wait.
show_frame:
    addi sp, sp, -4
    sw   ra, 0(sp)
    jal  ra, render_cube
    li   t0, DUMP
    beqz t0, sf_wait
    jal  ra, dump_frame
sf_wait:
    jal  ra, delay
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret
