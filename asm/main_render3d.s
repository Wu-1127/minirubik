# 3D render build (Ripes GUI with a 35 x 25 LED matrix).
# Shows the scrambled cube, solves it, then animates every move of the
# solver's path[]: the turning layer rotates in 3D, 11.25 degrees per frame
# (8 frames per quarter turn, 16 per half turn), while the other cubies stay.
# After the last animation frame the move is applied to the cubie state and
# the cube is drawn at rest.

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
    jal  ra, compute_colors
    li   a0, CAM_YAW
    jal  ra, build_camera
    li   a0, -1
    li   a1, 0
    jal  ra, frame           # the scrambled cube

    la   a0, input
    jal  ra, solve_input     # a0 = length, path[] = moves
    mv   s0, a0              # s0 = number of moves
    li   s1, 0               # s1 = i
r3_move:
    beq  s1, s0, r3_done
    la   t0, path
    add  t0, t0, s1
    lbu  s2, 0(t0)           # s2 = move
    la   t0, move_anim
    slli t1, s2, 2
    add  t0, t0, t1
    lb   s3, 2(t0)           # s3 = angle step per frame (+1 or -1)
    lbu  s4, 3(t0)           # s4 = frames for the whole turn (8 or 16)
    li   s5, 1               # s5 = frame t
r3_anim:
    beq  s5, s4, r3_apply    # the last angle equals the state after the move
    mv   a0, s2
    li   a1, 0               # angle = step * t, with step = +1 or -1
    bgtz s3, r3_pos
    sub  a1, a1, s5
    j    r3_ang
r3_pos:
    add  a1, a1, s5
r3_ang:
    jal  ra, frame
    addi s5, s5, 1
    j    r3_anim
r3_apply:
    mv   a0, s2
    jal  ra, apply_move
    jal  ra, compute_colors
    li   a0, -1
    li   a1, 0
    jal  ra, frame           # the cube at rest after the move
    addi s1, s1, 1
    j    r3_move
r3_done:
    mv   a0, s0
    jal  ra, print_path
    li   a7, 10              # exit
    ecall

# frame: a0 = move (-1: none), a1 = angle step. Draw, optionally dump, wait.
frame:
    addi sp, sp, -4
    sw   ra, 0(sp)
    jal  ra, draw_cubies
    li   t0, DUMP
    beqz t0, fr_wait
    jal  ra, dump_frame
fr_wait:
    jal  ra, delay
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret
