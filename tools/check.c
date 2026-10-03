/* Host-side correctness gates for the IDA* solver.
 *   H1: the heuristic never exceeds the true distance, for every state.
 *   H3: IDA* returns a shortest solution for every state,
 *       and applying that solution reaches the solved state.
 * True distances come from a BFS over all 3,674,160 states.
 *
 * Usage: tools/check          all states (takes minutes)
 *        tools/check --hard   only the states at distance 11
 */
#define IDA_NO_MAIN
#include "../ida.c"

#include <string.h>
#include <time.h>

enum { PERMUTATIONS = 5040, STATES = PERMUTATIONS * ORIENTATIONS };

static uint8_t true_dist[STATES];
static uint32_t queue[STATES];

/* Copied from solver.c, used only to print a state as 14 digits. */
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

static void state_string(uint32_t rank, char out[15])
{
    state_t s;
    unrank_state(rank, &s);
    for (int i = 0; i < CUBIES; ++i) {
        out[i] = (char) ('1' + s.p[i]);
        out[i + CUBIES] = (char) ('1' + s.o[i]);
    }
    out[14] = '\0';
}

/* Oracle: BFS over the full state space, using the same transition tables. */
static int build_true_dist(void)
{
    uint32_t head = 0, tail = 0;
    uint8_t max = 0;
    memset(true_dist, 0xFF, sizeof true_dist);
    true_dist[0] = 0;
    queue[tail++] = 0;
    while (head < tail) {
        uint32_t s = queue[head++];
        uint16_t p = (uint16_t) (s / ORIENTATIONS);
        uint16_t o = (uint16_t) (s % ORIENTATIONS);
        for (uint8_t m = 0; m < MOVES; ++m) {
            uint32_t t = (uint32_t) perm_move[p][m] * ORIENTATIONS +
                         orient_move[o][m];
            if (true_dist[t] == 0xFF) {
                true_dist[t] = (uint8_t) (true_dist[s] + 1U);
                if (true_dist[t] > max)
                    max = true_dist[t];
                queue[tail++] = t;
            }
        }
    }
    printf("Oracle: BFS reached %u of %u states, diameter %u\n", tail,
           (unsigned) STATES, max);
    return tail == STATES && max == MAX_DEPTH;
}

/* H1: h(s) <= true distance for every state. */
static int check_h1(void)
{
    unsigned long gap[MAX_DEPTH + 1] = {0}, violations = 0;
    for (uint32_t s = 0; s < STATES; ++s) {
        uint8_t hv = h((uint16_t) (s / ORIENTATIONS),
                       (uint16_t) (s % ORIENTATIONS));
        if (hv > true_dist[s])
            ++violations;
        else
            ++gap[true_dist[s] - hv];
    }
    printf("H1: %lu violations of h <= true distance\n", violations);
    printf("    true distance minus h:\n");
    for (int d = 0; d <= MAX_DEPTH; ++d)
        if (gap[d])
            printf("      %2d: %8lu states\n", d, gap[d]);
    return violations == 0;
}

/* H3: IDA* is optimal and its solution is real, for every (or every hard) state. */
static int check_h3(int hard_only)
{
    unsigned long count[MAX_DEPTH + 1] = {0}, max_nodes[MAX_DEPTH + 1] = {0};
    double total_nodes[MAX_DEPTH + 1] = {0};
    unsigned long wrong_length = 0, not_solved = 0, worst = 0;
    uint32_t worst_rank = 0;
    clock_t start = clock();

    for (uint32_t s = 0; s < STATES; ++s) {
        uint8_t d = true_dist[s];
        if (hard_only && d != MAX_DEPTH)
            continue;
        uint16_t p = (uint16_t) (s / ORIENTATIONS);
        uint16_t o = (uint16_t) (s % ORIENTATIONS);

        nodes = 0;
        uint8_t length = solve(p, o);

        if (length != d && wrong_length++ < 5)
            printf("    rank %u: length %u, true distance %u\n", s, length, d);

        for (uint8_t i = 0; i < length; ++i) {
            p = perm_move[p][path[i]];
            o = orient_move[o][path[i]];
        }
        if ((p != 0 || o != 0) && not_solved++ < 5)
            printf("    rank %u: solution does not reach solved state\n", s);

        ++count[d];
        total_nodes[d] += (double) nodes;
        if (nodes > max_nodes[d])
            max_nodes[d] = nodes;
        if (nodes > worst) {
            worst = nodes;
            worst_rank = s;
        }
        if (!hard_only && s % 500000 == 0)
            fprintf(stderr, "    progress: %u / %u\n", s, (unsigned) STATES);
    }

    double seconds = (double) (clock() - start) / CLOCKS_PER_SEC;
    printf("H3: %lu wrong lengths, %lu solutions not reaching solved\n",
           wrong_length, not_solved);
    printf("    distance   states   mean nodes    max nodes\n");
    for (int d = 0; d <= MAX_DEPTH; ++d)
        if (count[d])
            printf("    %8d %8lu %12.1f %12lu\n", d, count[d],
                   total_nodes[d] / (double) count[d], max_nodes[d]);
    char text[15];
    state_string(worst_rank, text);
    printf("    worst case: %lu nodes for state %s (distance %u)\n", worst,
           text, true_dist[worst_rank]);
    printf("    elapsed: %.1f s\n", seconds);
    return wrong_length == 0 && not_solved == 0;
}

int main(int argc, char **argv)
{
    int hard_only = argc > 1 && !strcmp(argv[1], "--hard");
    int ok = build_true_dist();
    ok = check_h1() && ok;
    ok = check_h3(hard_only) && ok;
    printf("%s\n", ok ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED");
    return ok ? 0 : 1;
}