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
# Frames: one per depth 0..10, 5 words each (20 bytes):
#   0: &perm_move[p][3 * face]   4: &orient_move[o][3 * face]   8: face
#   12: last face   16: resume address (code of the next turn)
frames:
    .zero 220
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
#   s3 bound        s4 next_bound   s5 g
#   s6 p, then g + 1            s7 o, then limit = bound - g - 1
#   s8 last face    a5 face         a6 &perm_move[p][3 * face]   a7 &orient_move[o][3 * face]
#   a3 child p      a4 child o      a1 frame pointer (frames + 20 * g)
# The three turns of a face are unrolled. A frame records where to resume
# in the parent: the address of the next turn's code.
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

    slli t3, s6, 4           # a6 = perm_move + 18 * p
    slli t4, s6, 1
    add  t3, t3, t4
    add  a6, t2, t3
    slli t3, s7, 4           # a7 = orient_move + 18 * o
    slli t4, s7, 1
    add  t3, t3, t4
    add  a7, a0, t3

    addi s6, s5, 1           # s6 = g + 1 (p is no longer needed)
    sub  s7, s3, s6          # s7 = limit = bound - (g + 1): keep a child if h <= limit
    li   a5, 0               # face = 0

face_loop:
    beq  a5, t6, node_done   # all three faces tried
    beq  a5, s8, face_next   # never turn the face just turned
turn0:
    lhu  a3, 0(a6)          # child p = perm_move[p][3 * face + 0]
    lhu  a4, 0(a7)          # child o = orient_move[o][3 * face + 0]
    add  t3, t0, a3
    lbu  t3, 0(t3)           # perm_dist[child p]
    add  t4, t1, a4
    lbu  t4, 0(t4)           # orient_dist[child o]
    bgeu t3, t4, h0
    mv   t3, t4              # h = max of the two
h0:
    bgeu s7, t3, desc0       # h <= limit: expand this child
    add  t3, t3, s6          # pruned: f = h + g + 1
    bgeu t3, s4, turn1
    mv   s4, t3              # next_bound = min(next_bound, f)
turn1:
    lhu  a3, 2(a6)          # child p = perm_move[p][3 * face + 1]
    lhu  a4, 2(a7)          # child o = orient_move[o][3 * face + 1]
    add  t3, t0, a3
    lbu  t3, 0(t3)           # perm_dist[child p]
    add  t4, t1, a4
    lbu  t4, 0(t4)           # orient_dist[child o]
    bgeu t3, t4, h1
    mv   t3, t4              # h = max of the two
h1:
    bgeu s7, t3, desc1       # h <= limit: expand this child
    add  t3, t3, s6          # pruned: f = h + g + 1
    bgeu t3, s4, turn2
    mv   s4, t3              # next_bound = min(next_bound, f)
turn2:
    lhu  a3, 4(a6)          # child p = perm_move[p][3 * face + 2]
    lhu  a4, 4(a7)          # child o = orient_move[o][3 * face + 2]
    add  t3, t0, a3
    lbu  t3, 0(t3)           # perm_dist[child p]
    add  t4, t1, a4
    lbu  t4, 0(t4)           # orient_dist[child o]
    bgeu t3, t4, h2
    mv   t3, t4              # h = max of the two
h2:
    bgeu s7, t3, desc2       # h <= limit: expand this child
    add  t3, t3, s6          # pruned: f = h + g + 1
    bgeu t3, s4, face_next
    mv   s4, t3              # next_bound = min(next_bound, f)
face_next:
    addi a6, a6, 6           # next face: 3 moves = 6 bytes further in each row
    addi a7, a7, 6
    addi a5, a5, 1
    j    face_loop

desc0:
    li   t4, 0               # turn within the face
    la   t5, turn1           # where the parent resumes
    j    descend
desc1:
    li   t4, 1
    la   t5, turn2
    j    descend
desc2:
    li   t4, 2
    la   t5, face_next

descend:
    slli t3, a5, 1           # path[g] = 3 * face + turn
    add  t3, t3, a5
    add  t4, t3, t4
    add  t3, a2, s5
    sb   t4, 0(t3)
    sw   a6, 0(a1)           # save the parent's loop state
    sw   a7, 4(a1)
    sw   a5, 8(a1)
    sw   s8, 12(a1)
    sw   t5, 16(a1)
    addi a1, a1, 20
    addi s5, s5, 1           # g += 1
    mv   s6, a3              # move to the child
    mv   s7, a4
    mv   s8, a5              # its previous face is this face
    j    node

node_done:
    beqz s5, iteration_failed
    addi a1, a1, -20         # return to the parent
    addi s5, s5, -1
    lw   a6, 0(a1)
    lw   a7, 4(a1)
    lw   a5, 8(a1)
    lw   s8, 12(a1)
    lw   t5, 16(a1)
    addi s6, s5, 1           # recompute g + 1 and limit for the parent
    sub  s7, s3, s6
    jr   t5                  # resume at the parent's next turn

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

