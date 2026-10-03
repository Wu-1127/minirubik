# Solver core, shared by every build.
# Concatenated after one asm/main_*.s file and before asm/tables.s
# (see tools/build.sh).
#
# Search state: permutation rank p (0..5039) and orientation rank o (0..728).
# Moves are table lookups: perm_move[p][m], orient_move[o][m], rows of 18 bytes.
# h = max(perm_dist[p], orient_dist[o]).
# The recursive search of ida.c becomes a loop with an explicit stack of
# frames, one frame per depth.

    .data
    .align 2
# Frames: one per depth 0..10, 6 words each (24 bytes):
#   0: prow   4: orow   8: move offset (2 * m)   12: face   16: turns left   20: last face
frames:
    .zero 264
path:
    .zero 12                 # path[g] = move index 0..8
# Move names, 2 bytes each (letter, suffix or 0): R R2 R' B B2 B' D D2 D'
# ASCII: R = 82, B = 66, D = 68, '2' = 50, apostrophe = 39
names:
    .byte 82, 0, 82, 50, 82, 39
    .byte 66, 0, 66, 50, 66, 39
    .byte 68, 0, 68, 50, 68, 39
    .align 2                 # asm/tables.s follows: keep its halfwords aligned

    .text
# ---------------------------------------------------------------------------
# solve_input: find a shortest solution.
#   in:  a0 = address of the 14-character state
#   out: a0 = solution length, a1 = root p, a2 = root o; path[0..a0-1] = moves
# Uses s0-s11, t0-t6, a0-a7. Calls nothing, so ra is preserved.
# ---------------------------------------------------------------------------
solve_input:
    mv   s0, a0

# ---- Orientation rank -> s2 ----------------------------------------------
    li   s2, 0
    lbu  t0, 7(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0
    lbu  t0, 8(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0
    lbu  t0, 9(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0
    lbu  t0, 10(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0
    lbu  t0, 11(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0
    lbu  t0, 12(s0)
    addi t0, t0, -49
    slli t1, s2, 1
    add  t1, t1, s2
    add  s2, t1, t0

# ---- Permutation rank -> s1 ----------------------------------------------
    li   s1, 0
    li   t3, 7
    mv   t4, s0
    addi t5, s0, 7
loop_i:
    lbu  t0, 0(t4)
    li   t6, 0
    addi a1, t4, 1
loop_j:
    beq  a1, t5, end_j
    lbu  a2, 0(a1)
    bgeu a2, t0, skip
    addi t6, t6, 1
skip:
    addi a1, a1, 1
    j    loop_j
end_j:
    li   a3, 0
    mv   a4, t3
mul_loop:
    add  a3, a3, s1
    addi a4, a4, -1
    bnez a4, mul_loop
    add  s1, a3, t6
    addi t3, t3, -1
    addi t4, t4, 1
    bne  t4, t5, loop_i

# ---- Table base addresses (kept in registers for the whole search) -------
    la   t0, perm_dist
    la   t1, orient_dist
    la   t2, perm_move
    la   a0, orient_move
    la   a2, path
    li   t6, 3               # constant 3: number of faces, and "no face"

# ---- IDA*: bound = h(root) -----------------------------------------------
    add  t3, t0, s1
    lbu  t3, 0(t3)           # perm_dist[p]
    add  t4, t1, s2
    lbu  t4, 0(t4)           # orient_dist[o]
    bgeu t3, t4, root_h
    mv   t3, t4
root_h:
    mv   s3, t3              # s3 = bound

# Register use during the search:
#   s3 bound        s4 next_bound   s5 g            s6 p          s7 o
#   s8 last face    s9 prow         s10 orow        s11 2 * m
#   a5 face         a6 turns left   a3 child p      a4 child o
#   a1 frame pointer (frames + 24 * g)
iteration:
    li   s4, 255             # next_bound = infinity
    li   s5, 0               # g = 0
    la   a1, frames
    mv   s6, s1              # start at the root
    mv   s7, s2
    mv   s8, t6              # no previous face

node:
    or   t3, s6, s7
    beqz t3, found           # (p, o) == (0, 0): solved

    slli t3, s6, 4           # prow = perm_move + 18 * p
    slli t4, s6, 1
    add  t3, t3, t4
    add  s9, t2, t3
    slli t3, s7, 4           # orow = orient_move + 18 * o
    slli t4, s7, 1
    add  t3, t3, t4
    add  s10, a0, t3

    li   s11, 0              # m = 0 (byte offset 2 * m)
    li   a5, 0               # face = 0
face_loop:
    beq  a5, t6, node_done   # all three faces tried
    bne  a5, s8, face_ok
    addi s11, s11, 6         # skip the face just turned: 3 moves
    addi a5, a5, 1
    j    face_loop
face_ok:
    li   a6, 3               # three turns of this face
turn_loop:
    add  t3, s9, s11
    lhu  a3, 0(t3)           # child p = prow[m]
    add  t3, s10, s11
    lhu  a4, 0(t3)           # child o = orow[m]

    add  t3, t0, a3
    lbu  t3, 0(t3)           # perm_dist[child p]
    add  t4, t1, a4
    lbu  t4, 0(t4)           # orient_dist[child o]
    bgeu t3, t4, h_done
    mv   t3, t4
h_done:
    add  t3, t3, s5
    addi t3, t3, 1           # f = g + 1 + h(child)
    bgeu s3, t3, descend     # f <= bound: expand the child

    bgeu t3, s4, next_turn   # pruned: next_bound = min(next_bound, f)
    mv   s4, t3
    j    next_turn

descend:
    srli t4, s11, 1          # path[g] = m
    add  t5, a2, s5
    sb   t4, 0(t5)
    sw   s9, 0(a1)           # save this node's loop state
    sw   s10, 4(a1)
    sw   s11, 8(a1)
    sw   a5, 12(a1)
    sw   a6, 16(a1)
    sw   s8, 20(a1)
    addi a1, a1, 24
    addi s5, s5, 1           # g += 1
    mv   s6, a3              # move to the child
    mv   s7, a4
    mv   s8, a5              # its previous face is this face
    j    node

next_turn:
    addi s11, s11, 2         # m += 1
    addi a6, a6, -1
    bnez a6, turn_loop
    addi a5, a5, 1           # next face
    j    face_loop

node_done:
    beqz s5, iteration_failed
    addi a1, a1, -24         # return to the parent
    addi s5, s5, -1
    lw   s9, 0(a1)
    lw   s10, 4(a1)
    lw   s11, 8(a1)
    lw   a5, 12(a1)
    lw   a6, 16(a1)
    lw   s8, 20(a1)
    j    next_turn

iteration_failed:
    mv   s3, s4              # bound = next_bound
    j    iteration

found:
    mv   a0, s5              # solution length
    mv   a1, s1              # root ranks, for verify
    mv   a2, s2
    ret

# ---------------------------------------------------------------------------
# print_path: print path[0..a0-1] as move names separated by spaces, then a newline.
#   in: a0 = solution length.   Uses t0-t5, a0, a7; preserves a1, a2.
# ---------------------------------------------------------------------------
print_path:
    mv   t5, a0
    la   t2, path
    la   t1, names
    li   t0, 0               # i = 0
pp_loop:
    beq  t0, t5, pp_end
    beqz t0, pp_move         # no space before the first move
    li   a0, 32
    li   a7, 11
    ecall
pp_move:
    add  t3, t2, t0
    lbu  t3, 0(t3)           # m = path[i]
    slli t3, t3, 1           # names + 2 * m
    add  t3, t1, t3
    lbu  a0, 0(t3)           # face letter
    li   a7, 11
    ecall
    lbu  a0, 1(t3)           # suffix, or 0 for a plain quarter turn
    beqz a0, pp_next
    ecall
pp_next:
    addi t0, t0, 1
    j    pp_loop
pp_end:
    li   a0, 10              # newline
    li   a7, 11
    ecall
    ret

# ---------------------------------------------------------------------------
# verify: replay path[0..a0-1] from (a1, a2) with the transition tables.
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
