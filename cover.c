#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include "cover.h"

#define COVER_INITIAL_SIZE 1

#define BIT_TURN_ON(data, bit)   data[bit/CHAR_BIT] |=  (1 << (bit%CHAR_BIT))
#define BIT_TURN_OFF(data, bit)  data[bit/CHAR_BIT] &= ~(1 << (bit%CHAR_BIT))
#define BIT_IS_ON(data, bit)    (data[bit/CHAR_BIT] &   (1 << (bit%CHAR_BIT)))

static void cover_set(CoverNode* cn, int line);

CoverList* cover_create(void) {
  CoverList* cl = (CoverList*) malloc(sizeof(CoverList));
  cl->head = 0;
  cl->size = 0;
  return cl;
}

void cover_destroy(CoverList* cover) {
  if (!cover) {
    return;
  }

  for (CoverNode* cn = cover->head; cn != 0; ) {
    CoverNode* p = cn;
    // fprintf(stderr, "Destroying set for [%s], %d/%d elements\n", cn->file, cn->ulen, cn->alen*CHAR_BIT);
    cn = cn->next;
    free(p->file);
    free(p->lines);
    free(p);
  }
}

CoverNode* cover_add(CoverList* cover, const char* file, int line) {
  CoverNode* cn = 0;
  for (cn = cover->head; cn != 0; cn = cn->next) {
    if (strcmp(cn->file, file) == 0) {
      break;
    }
  }
  if (cn == 0) {
    cn = (CoverNode*) malloc(sizeof(CoverNode));
    cn->file = strdup(file);
    cn->lines = 0;
    cn->alen = cn->ulen = 0;
    cn->next = cover->head;
    cover->head = cn;
    // fprintf(stderr, "Adding set for [%s]\n", cn->file);
  }
  cover_set(cn, line);
  return cn;
}

void cover_dump(CoverList* cover, FILE* fp) {
  for (CoverNode* cn = cover->head; cn != 0; cn = cn->next) {
    fprintf(fp, "Quick coverage for file [%s]:\n", cn->file);
    for (int j = 0; j < cn->ulen; ++j) {
      if (BIT_IS_ON(cn->lines, j)) {
        fprintf(fp, "  %d\n", j+1);
      }
    }
  }
}

static void cover_set(CoverNode* cn, int line) {
  // fprintf(stderr, "Adding line %d for [%s]\n", line, cn->file);
  if (cn->ulen < line) {
    cn->ulen = line;
  }

  --line; // store line numbers zero-based
  int needed = line / CHAR_BIT + 1;
  if (cn->alen < needed) {
    int size = cn->alen ? cn->alen : COVER_INITIAL_SIZE;
    while (size < needed) {
      size *= 2;
    }
    // fprintf(stderr, "Growing map for [%s] from %d to %d\n", cn->file, cn->alen, size);
    cn->lines = realloc(cn->lines, size);
    memset(cn->lines + cn->alen, 0, size - cn->alen);
    cn->alen = size;
  }
  BIT_TURN_ON(cn->lines, line);
}
