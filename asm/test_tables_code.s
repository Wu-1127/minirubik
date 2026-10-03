    .text
    .globl main
main:
    la   t0, perm_move
    lhu  t1, 0(t0)        # t1 = perm_move[0][0], the rank after R

    slli t2, t1, 4        # t2 = t1 * 16
    slli t3, t1, 1        # t3 = t1 * 2
    add  t2, t2, t3       # t2 = t1 * 18, byte offset of row t1
    add  t2, t2, t0       # t2 = address of perm_move[t1][0]
    lhu  a0, 4(t2)        # perm_move[t1][2] (R'), expect 0
    li   a7, 1
    ecall

    li   a0, 32
    li   a7, 11
    ecall

    la   t0, perm_dist
    add  t0, t0, t1       # address of perm_dist[t1]
    lbu  a0, 0(t0)        # expect 1
    li   a7, 1
    ecall

    li   a7, 10
    ecall
