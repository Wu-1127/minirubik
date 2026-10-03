/* List every state at a given distance, with the C solver's node counts
 * and solution, for comparison with the assembly version.
 * Usage: tools/list_states DISTANCE > list.txt
 * Output: state distance nodes generated solution(comma-separated)
 */
#define IDA_NO_MAIN
#include "../ida.c"

#include <stdlib.h>
#include <string.h>

enum { STATES = 5040 * 729 };
static uint8_t dist[STATES];
static uint32_t queue[STATES];

static void unrank(uint32_t rank, state_t *s)
{
    uint8_t av[7] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / 729, o = rank % 729, f = 720;
    uint8_t sum = 0;
    for (int i = 0; i < 7; ++i) {
        uint8_t q = (uint8_t) (p / f);
        p %= f;
        s->p[i] = av[q];
        for (int j = q; j + 1 < 7 - i; ++j)
            av[j] = av[j + 1];
        if (i < 5)
            f /= 6 - i;
    }
    for (int i = 6; i-- > 0;) {
        s->o[i] = (uint8_t) (o % 3);
        sum = (uint8_t) (sum + s->o[i]);
        o /= 3;
    }
    s->o[6] = (uint8_t) ((3 - sum % 3) % 3);
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s DISTANCE\n", argv[0]);
        return 2;
    }
    int want = atoi(argv[1]);

    uint32_t head = 0, tail = 0;
    memset(dist, 0xFF, sizeof dist);
    dist[0] = 0;
    queue[tail++] = 0;
    while (head < tail) {
        uint32_t s = queue[head++];
        uint16_t p = (uint16_t) (s / 729), o = (uint16_t) (s % 729);
        for (int m = 0; m < 9; ++m) {
            uint32_t t = (uint32_t) perm_move[p][m] * 729 + orient_move[o][m];
            if (dist[t] == 0xFF) {
                dist[t] = (uint8_t) (dist[s] + 1);
                queue[tail++] = t;
            }
        }
    }

    for (uint32_t s = 0; s < STATES; ++s) {
        if (dist[s] != want)
            continue;
        state_t st;
        unrank(s, &st);
        char text[15];
        for (int i = 0; i < 7; ++i) {
            text[i] = (char) ('1' + st.p[i]);
            text[i + 7] = (char) ('1' + st.o[i]);
        }
        text[14] = '\0';

        nodes = generated = 0;
        uint8_t length = solve((uint16_t) (s / 729), (uint16_t) (s % 729));
        printf("%s %d %lu %lu ", text, dist[s], nodes, generated);
        for (uint8_t i = 0; i < length; ++i)
            printf("%s%s", i ? "," : "", move_names[path[i]]);
        printf("\n");
    }
    return 0;
}