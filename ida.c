#include <stdint.h>
#include <stdio.h>
#include "tools/tables.h"

enum {
    CUBIES = 7,
    ORIENTATIONS = 729,
    MOVES = 9,
    MAX_DEPTH = 11,
    NO_FACE = 3
};

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const char *const move_names[MOVES] = {"R",  "R2", "R'", "B", "B2",
                                              "B'", "D",  "D2", "D'"};

/* ---- Input handling, copied from solver.c ---- */

static int valid(const state_t *state)
{
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        if (state->p[i] >= CUBIES || state->o[i] >= 3)
            return 0;
        for (uint8_t j = 0; j < i; ++j)
            if (state->p[j] == state->p[i])
                return 0;
        sum = (uint8_t) (sum + state->o[i]);
    }
    return sum % 3U == 0;
}

static int parse_state(const char *input, state_t *state)
{
    for (int i = 0; i < 14; ++i) {
        int limit = i < 7 ? 7 : 3;
        if (input[i] < '1' || input[i] > '0' + limit)
            return 0;
        (i < 7 ? state->p : state->o)[i % 7] = (uint8_t) (input[i] - '1');
    }
    return input[14] == '\0' && valid(state);
}

static uint32_t rank_state(const state_t *state)
{
    uint32_t p = 0, o = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t smaller = 0;
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; ++j)
            if (state->p[j] < state->p[i])
                ++smaller;
        p = p * (CUBIES - i) + smaller;
    }
    for (uint8_t i = 0; i < 6; ++i)
        o = o * 3U + state->o[i];
    return p * ORIENTATIONS + o;
}

/* ---- Search ---- */

static uint8_t h(uint16_t p, uint16_t o)
{
    uint8_t a = perm_dist[p];
    uint8_t b = orient_dist[o];
    return a > b ? a : b;
}

static uint8_t path[MAX_DEPTH];
static uint8_t solution_length;
static uint8_t next_bound;
static unsigned long nodes;

/* Depth-first search below the current bound.
 * Returns 1 if a solution is found; path[0..g-1] then holds it. */
static int search(uint16_t p, uint16_t o, uint8_t g, uint8_t bound,
                  uint8_t last_face)
{
    ++nodes;
    uint8_t f = (uint8_t) (g + h(p, o));

    /* 1. Prune: this path cannot finish within the bound.
     *    Remember the smallest f that exceeded it, for the next iteration. */
    if (f > bound) {
        if (f < next_bound)
            next_bound = f;
        return 0;
    }

    /* 2. Goal test: the solved state is rank (0, 0). */
    if (p == 0 && o == 0) {
        solution_length = g;
        return 1;
    }

    /* 3. Try every move except those on the face just turned. */
    for (uint8_t m = 0; m < MOVES; ++m) {
        uint8_t face = (uint8_t) (m / 3U);
        if (face == last_face)
            continue;
        path[g] = m;
        /* 4. Recurse; stop as soon as any child finds a solution. */
        if (search(perm_move[p][m], orient_move[o][m], (uint8_t) (g + 1U),
                   bound, face))
            return 1;
    }
    return 0;
}

/* Iterative deepening on f: raise the bound until a solution is found. */
static uint8_t solve(uint16_t p, uint16_t o)
{
    uint8_t bound = h(p, o);
    for (;;) {
        next_bound = UINT8_MAX;
        if (search(p, o, 0, bound, NO_FACE))
            return solution_length;
        bound = next_bound;
    }
}

#ifndef IDA_NO_MAIN
int main(int argc, char **argv)
{
    state_t state;
    if (argc != 2 || !parse_state(argv[1], &state)) {
        fprintf(stderr, "usage: %s PPPPPPPOOOOOOO\n",
                argc > 0 && argv[0] ? argv[0] : "ida");
        return 2;
    }
    uint32_t rank = rank_state(&state);
    uint16_t p = (uint16_t) (rank / ORIENTATIONS);
    uint16_t o = (uint16_t) (rank % ORIENTATIONS);

    uint8_t length = solve(p, o);
    for (uint8_t i = 0; i < length; ++i)
        printf("%s%s", i ? " " : "", move_names[path[i]]);
    putchar('\n');
    fprintf(stderr, "length %u, nodes %lu\n", length, nodes);
    return 0;
}
#endif