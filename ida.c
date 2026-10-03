/* IDA* solver for the 2x2x2 cube using pattern databases.
 * Usage: ./ida PPPPPPPOOOOOOO
 * The solution goes to stdout; search statistics go to stderr.
 */
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
static unsigned long nodes;     /* calls to search: nodes actually expanded */
static unsigned long generated; /* children whose f was evaluated */

/* Depth-first search below the current bound.
 * The caller guarantees f = g + h(p, o) <= bound, so this function never
 * has to prune itself; it prunes its children before calling into them.
 * Returns 1 if a solution is found; path[0..solution_length-1] then holds it.
 *
 * path[g] cannot overflow: a child is entered only if g + 1 + h <= bound <= 11.
 * At g = 11 that requires h = 0, which holds only for the solved state (0, 0),
 * and the goal test returns before the loop writes path[11]. */
static int search(uint16_t p, uint16_t o, uint8_t g, uint8_t bound,
                  uint8_t last_face)
{
    ++nodes;

    /* Goal test: the solved state is rank (0, 0). */
    if (p == 0 && o == 0) {
        solution_length = g;
        return 1;
    }

    /* Row bases are computed once per node, so the inner loop needs no
     * multiplication: prow[m] instead of perm_move[p][m] = base + (9p + m) * 2. */
    const uint16_t *prow = perm_move[p];
    const uint16_t *orow = orient_move[o];

    /* Two nested loops replace m / 3: the face is the outer loop variable,
     * and a skipped face skips its three moves at once. */
    uint8_t m = 0;
    for (uint8_t face = 0; face < 3; ++face) {
        if (face == last_face) {
            m = (uint8_t) (m + 3U);
            continue;
        }
        for (uint8_t turn = 0; turn < 3; ++turn, ++m) {
            uint16_t np = prow[m];
            uint16_t no = orow[m];
            uint8_t f = (uint8_t) (g + 1U + h(np, no));
            ++generated;

            /* Prune the child here instead of calling into it. */
            if (f > bound) {
                if (f < next_bound)
                    next_bound = f;
                continue;
            }

            path[g] = m;
            if (search(np, no, (uint8_t) (g + 1U), bound, face))
                return 1;
        }
    }
    return 0;
}

/* Iterative deepening on f: raise the bound until a solution is found.
 * The root needs no f check: the first bound is h(root), and later bounds
 * are larger, so f(root) = h(root) <= bound always holds. */
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
    fprintf(stderr, "length %u, nodes %lu, generated %lu\n", length, nodes,
            generated);
    return 0;
}
#endif