# Test build: solve each test state, print the solution, replay it with the
# transition tables, and check that it reaches the solved state in the
# expected number of moves. Prints PASS or FAIL per test and a summary.

    .equ NTESTS, 5

    .data
# Each test is 16 bytes: 14 characters, NUL, expected solution length.
tests:
    .string "12345671111111"     # solved
    .byte 0
    .string "12356741112323"     # distance 1
    .byte 1
    .string "12435761111111"     # distance 3
    .byte 3
    .string "21345671111111"     # distance 11, the state the assignment asks to report
    .byte 11
    .string "54721631111111"     # distance 11, worst case on RV32_ISS
    .byte 11
msg_pass:
    .string "PASS"
msg_fail:
    .string "FAIL"
msg_summary:
    .string "passed "

    .text
    .globl main
main:
    li   sp, 0x7ffffff0      # same as the GUI default; CLI starts with sp = 0
    addi sp, sp, -16         # locals: 0 test pointer, 4 passed, 8 index, 12 length
    la   t0, tests
    sw   t0, 0(sp)
    sw   zero, 4(sp)
    sw   zero, 8(sp)

t_loop:
    lw   t0, 8(sp)
    li   t1, NTESTS
    beq  t0, t1, t_done

    lw   a0, 0(sp)
    jal  ra, solve_input     # a0 = length, a1 = root p, a2 = root o
    sw   a0, 12(sp)
    jal  ra, print_path      # preserves a1, a2
    lw   a0, 12(sp)
    jal  ra, verify          # a0 = 1 if the solution reaches (0, 0)

    lw   t0, 0(sp)
    lbu  t1, 15(t0)          # expected length
    lw   t2, 12(sp)
    bne  t1, t2, t_fail      # wrong length
    beqz a0, t_fail          # does not solve the cube

    la   a0, msg_pass
    jal  ra, print_str
    lw   t0, 4(sp)
    addi t0, t0, 1
    sw   t0, 4(sp)
    j    t_next
t_fail:
    la   a0, msg_fail
    jal  ra, print_str
t_next:
    lw   t0, 0(sp)
    addi t0, t0, 16
    sw   t0, 0(sp)
    lw   t0, 8(sp)
    addi t0, t0, 1
    sw   t0, 8(sp)
    j    t_loop

t_done:
    la   a0, msg_summary     # "passed N/NTESTS"
    jal  ra, print_str_nonl
    lw   a0, 4(sp)
    li   a7, 1
    ecall
    li   a0, 47              # '/'
    li   a7, 11
    ecall
    li   a0, NTESTS
    li   a7, 1
    ecall
    li   a0, 10
    li   a7, 11
    ecall
    li   a7, 10              # exit
    ecall

# print_str: print the NUL-terminated string at a0, then a newline.
print_str:
    mv   t0, a0
ps_loop:
    lbu  a0, 0(t0)
    beqz a0, ps_end
    li   a7, 11
    ecall
    addi t0, t0, 1
    j    ps_loop
ps_end:
    li   a0, 10
    li   a7, 11
    ecall
    ret

# print_str_nonl: same without the newline.
print_str_nonl:
    mv   t0, a0
psn_loop:
    lbu  a0, 0(t0)
    beqz a0, psn_end
    li   a7, 11
    ecall
    addi t0, t0, 1
    j    psn_loop
psn_end:
    ret

# ---------------------------------------------------------------------------
# verify (test build only): replay path[0..a0-1] from (a1, a2) with the transition tables.
#   in:  a0 = length, a1 = root p, a2 = root o
#   out: a0 = 1 if the replay ends at the solved state (0, 0), else 0
# ---------------------------------------------------------------------------
verify:
    la   t0, perm_move
    la   t1, orient_move
    la   t2, path
    li   t3, 0               # i = 0
v_loop:
    beq  t3, a0, v_end
    add  t4, t2, t3
    lbu  t4, 0(t4)
    slli t4, t4, 1           # 2 * path[i]
    slli t5, a1, 4           # p = perm_move[p][m]
    slli t6, a1, 1
    add  t5, t5, t6
    add  t5, t5, t0
    add  t5, t5, t4
    lhu  a1, 0(t5)
    slli t5, a2, 4           # o = orient_move[o][m]
    slli t6, a2, 1
    add  t5, t5, t6
    add  t5, t5, t1
    add  t5, t5, t4
    lhu  a2, 0(t5)
    addi t3, t3, 1
    j    v_loop
v_end:
    or   a0, a1, a2
    seqz a0, a0              # a0 = (p | o) == 0
    ret
