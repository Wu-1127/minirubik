/* Generate the transition tables and pattern databases for the IDA* solver.
 *
 * Usage: tools/gen_tables > tools/tables.h
 * The C header goes to stdout; checks and statistics go to stderr.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

enum {
    CUBIES = 7,
    PERMUTATIONS = 5040,
    ORIENTATIONS = 729,
    MOVES = 9
};

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

/* ---- Copied from solver.c (Frama-C annotations removed) ---- */

static const uint8_t inverse_move[MOVES] = {2, 1, 0, 5, 4, 3, 8, 7, 6};
static const uint8_t source[3][CUBIES] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};
static const uint8_t twist[3][CUBIES] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};

static state_t quarter_turn(state_t state, uint8_t face)
{
    state_t result;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t from = source[face][i];
        result.p[i] = state.p[from];
        result.o[i] = (uint8_t) ((state.o[from] + twist[face][i]) % 3U);
    }
    return result;
}

static state_t apply_move(state_t state, uint8_t move)
{
    uint8_t turns = (uint8_t) (move % 3U + 1U);
    for (uint8_t i = 0; i < turns; ++i)
        state = quarter_turn(state, (uint8_t) (move / 3U));
    return state;
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

static void unrank_state(uint32_t rank, state_t *state)
{
    uint8_t available[CUBIES] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / ORIENTATIONS, o = rank % ORIENTATIONS, f = 720;
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t q = (uint8_t) (p / f);
        p %= f;
        state->p[i] = available[q];
        for (uint8_t j = q; j + 1U < CUBIES - i; ++j)
            available[j] = available[j + 1U];
        if (i < 5)
            f /= 6U - i;
    }
    for (uint8_t i = 6; i-- > 0;) {
        state->o[i] = (uint8_t) (o % 3U);
        sum = (uint8_t) (sum + state->o[i]);
        o /= 3U;
    }
    state->o[6] = (uint8_t) ((3U - sum % 3U) % 3U);
}

/* ---- New code ---- */

static uint16_t perm_move[PERMUTATIONS][MOVES];
static uint16_t orient_move[ORIENTATIONS][MOVES];
static uint8_t perm_dist[PERMUTATIONS];
static uint8_t orient_dist[ORIENTATIONS];

/* For every permutation rank and move, record the permutation rank after the move.
 * The orientation part is 0 and is ignored. */
static void build_perm_move(void)
{
    state_t state;
    for (uint16_t r = 0; r < PERMUTATIONS; ++r) {
        unrank_state((uint32_t) r * ORIENTATIONS, &state);
        for (uint8_t m = 0; m < MOVES; ++m) {
            state_t next = apply_move(state, m);
            perm_move[r][m] = (uint16_t) (rank_state(&next) / ORIENTATIONS);
        }
    }
}

/* Same for orientation ranks. The permutation part is the identity (rank 0). */
static void build_orient_move(void)
{
    state_t state;
    for (uint16_t r = 0; r < ORIENTATIONS; ++r) {
        unrank_state(r, &state);
        for (uint8_t m = 0; m < MOVES; ++m) {
            state_t next = apply_move(state, m);
            orient_move[r][m] = (uint16_t) (rank_state(&next) % ORIENTATIONS);
        }
    }
}

/* BFS from the solved index 0 over an abstract state space of n states.
 * move[s * MOVES + m] is the index reached from s by move m.
 * Returns the number of states reached. */
static uint16_t build_dist(const uint16_t *move, uint16_t n, uint8_t *dist)
{
    uint16_t queue[PERMUTATIONS];
    uint16_t head = 0, tail = 0;
    memset(dist, 0xFF, n);
    dist[0] = 0;
    queue[tail++] = 0;
    while (head < tail) {
        uint16_t s = queue[head++];
        for (uint8_t m = 0; m < MOVES; ++m) {
            uint16_t t = move[(uint32_t) s * MOVES + m];
            if (dist[t] == 0xFF) {
                dist[t] = (uint8_t) (dist[s] + 1U);
                queue[tail++] = t;
            }
        }
    }
    return tail;
}

/* Every entry is in range, and every move is undone by its inverse. */
static int check_moves(const char *name, const uint16_t *move, uint16_t n)
{
    for (uint16_t s = 0; s < n; ++s)
        for (uint8_t m = 0; m < MOVES; ++m) {
            uint16_t t = move[(uint32_t) s * MOVES + m];
            if (t >= n) {
                fprintf(stderr, "%s: entry [%u][%u] = %u out of range\n",
                        name, s, m, t);
                return 0;
            }
            if (move[(uint32_t) t * MOVES + inverse_move[m]] != s) {
                fprintf(stderr, "%s: move %u from %u is not undone\n",
                        name, m, s);
                return 0;
            }
        }
    fprintf(stderr, "%s: all %u x %u entries in range and invertible\n",
            name, n, (unsigned) MOVES);
    return 1;
}

/* Every state reached, and the distance histogram for the write-up. */
static int check_dist(const char *name, const uint8_t *dist, uint16_t n,
                      uint16_t reached)
{
    unsigned count[256] = {0};
    uint8_t max = 0;
    if (reached != n) {
        fprintf(stderr, "%s: BFS reached %u of %u states\n", name, reached, n);
        return 0;
    }
    for (uint16_t s = 0; s < n; ++s) {
        ++count[dist[s]];
        if (dist[s] > max)
            max = dist[s];
    }
    fprintf(stderr, "%s: %u states, max distance %u, dist[0] = %u\n", name, n,
            max, dist[0]);
    for (unsigned d = 0; d <= max; ++d)
        fprintf(stderr, "  distance %2u: %5u states\n", d, count[d]);
    return 1;
}

static void print_u16(const char *name, const uint16_t *t, unsigned rows)
{
    printf("static const uint16_t %s[%u][%u] = {\n", name, rows, (unsigned) MOVES);
    for (unsigned r = 0; r < rows; ++r) {
        printf("    {");
        for (unsigned m = 0; m < MOVES; ++m)
            printf("%u%s", t[r * MOVES + m], m + 1 < MOVES ? ", " : "");
        printf("},\n");
    }
    printf("};\n\n");
}

static void print_u8(const char *name, const uint8_t *t, unsigned n)
{
    printf("static const uint8_t %s[%u] = {", name, n);
    for (unsigned i = 0; i < n; ++i)
        printf("%s%u%s", i % 20 ? "" : "\n    ", t[i], i + 1 < n ? ", " : "");
    printf("\n};\n\n");
}

int main(void)
{
    build_perm_move();
    build_orient_move();
    uint16_t perm_reached =
        build_dist(&perm_move[0][0], PERMUTATIONS, perm_dist);
    uint16_t orient_reached =
        build_dist(&orient_move[0][0], ORIENTATIONS, orient_dist);

    if (!check_moves("perm_move", &perm_move[0][0], PERMUTATIONS) ||
        !check_moves("orient_move", &orient_move[0][0], ORIENTATIONS) ||
        !check_dist("perm_dist", perm_dist, PERMUTATIONS, perm_reached) ||
        !check_dist("orient_dist", orient_dist, ORIENTATIONS, orient_reached))
        return 1;

    printf("/* Generated by tools/gen_tables.c. Do not edit. */\n\n");
    print_u16("perm_move", &perm_move[0][0], PERMUTATIONS);
    print_u16("orient_move", &orient_move[0][0], ORIENTATIONS);
    print_u8("perm_dist", perm_dist, PERMUTATIONS);
    print_u8("orient_dist", orient_dist, ORIENTATIONS);
    return 0;
}