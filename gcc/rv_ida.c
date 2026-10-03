/* Freestanding build of the Stage 3 C solver for the gcc comparison.
 * Same algorithm and move order as ida.c; I/O through Ripes ecalls.
 * Build: riscv64-unknown-elf-gcc -O2 -march=rv32i -mabi=ilp32 ... (see Makefile)
 */
#include <stdint.h>
#include "../tools/tables.h"

#ifndef INPUT
#define INPUT "54721631111111"
#endif

static const char input[] = INPUT;
static const char move_names[9][3] = {"R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"};

static void putch(int c)
{
    register int a0 __asm__("a0") = c;
    register int a7 __asm__("a7") = 11;
    __asm__ volatile("ecall" : : "r"(a0), "r"(a7));
}

static uint8_t h(uint16_t p, uint16_t o)
{
    uint8_t a = perm_dist[p], b = orient_dist[o];
    return a > b ? a : b;
}

static uint8_t path[11], solution_length, next_bound;

static int search(uint16_t p, uint16_t o, uint8_t g, uint8_t bound, uint8_t last_face)
{
    if (p == 0 && o == 0) {
        solution_length = g;
        return 1;
    }
    const uint16_t *prow = perm_move[p];
    const uint16_t *orow = orient_move[o];
    uint8_t m = 0;
    for (uint8_t face = 0; face < 3; ++face) {
        if (face == last_face) {
            m = (uint8_t)(m + 3U);
            continue;
        }
        for (uint8_t turn = 0; turn < 3; ++turn, ++m) {
            uint16_t np = prow[m], no = orow[m];
            uint8_t f = (uint8_t)(g + 1U + h(np, no));
            if (f > bound) {
                if (f < next_bound)
                    next_bound = f;
                continue;
            }
            path[g] = m;
            if (search(np, no, (uint8_t)(g + 1U), bound, face))
                return 1;
        }
    }
    return 0;
}

static uint8_t solve(uint16_t p, uint16_t o)
{
    uint8_t bound = h(p, o);
    for (;;) {
        next_bound = 255;
        if (search(p, o, 0, bound, 3))
            return solution_length;
        bound = next_bound;
    }
}

int main(void)
{
    uint32_t p = 0, o = 0;
    for (int i = 0; i < 7; ++i) {
        int smaller = 0;
        for (int j = i + 1; j < 7; ++j)
            if (input[j] < input[i])
                ++smaller;
        p = p * (uint32_t)(7 - i) + (uint32_t)smaller;
    }
    for (int i = 7; i < 13; ++i)
        o = o * 3U + (uint32_t)(input[i] - '1');

    uint8_t length = solve((uint16_t)p, (uint16_t)o);
    for (uint8_t i = 0; i < length; ++i) {
        if (i)
            putch(' ');
        const char *n = move_names[path[i]];
        putch(n[0]);
        if (n[1])
            putch(n[1]);
    }
    putch('\n');
    return 0;
}

/* Entry point: set sp as the assembly does, call main, exit. */
__attribute__((naked, section(".text.start"))) void _start(void)
{
    __asm__ volatile(
        "li sp, 0x7ffffff0\n"
        "call main\n"
        "li a7, 10\n"
        "ecall\n");
}
