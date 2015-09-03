#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cover.h"

#define COVER_INITIAL_SIZE 8

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
    // fprintf(stderr, "Destroying set for [%s], %d/%d elements\n", cn->file, cn->bmax, cn->alen*CHAR_BIT);
    cn = cn->next;
    free(p->file);
    free(p->lines);
    free(p);
  }
  free(cover);
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
    // TODO: normalise name first? ./foo.pl, foo.pl, ../bar/foo.pl, etc.
    cn->file = strdup(file);
    cn->lines = 0;
    cn->alen = cn->ulen = cn->bmax = 0;
    cn->next = cover->head;
    cover->head = cn;
    ++cover->size;
    // fprintf(stderr, "Adding set for [%s]\n", cn->file);
  }
  cover_set(cn, line);
  return cn;
}

void cover_dump(CoverList* cover, FILE* fp, struct tm* tm) {
  if (tm == 0) {
    time_t t;
    time(&t);
    tm = localtime(&t);
  }
  fprintf(fp, "# These are comments. Each line block has the following fields:\n");
  fprintf(fp, "#\n");
  fprintf(fp, "# 0 number_of_files year month day hour minute second\n");
  fprintf(fp, "# 1 number_of_lines file_name\n");
  fprintf(fp, "# 2 line_covered\n");
  fprintf(fp, "# --------------\n");
  fprintf(fp, "0 %d %d %d %d %d %d %d\n",
          cover->size,
          tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday,
          tm->tm_hour, tm->tm_min, tm->tm_sec);
  for (CoverNode* cn = cover->head; cn != 0; cn = cn->next) {
    fprintf(fp, "1 %d %s\n", cn->ulen, cn->file);
    for (int j = 0; j < cn->bmax; ++j) {
      if (BIT_IS_ON(cn->lines, j)) {
        fprintf(fp, "2 %d\n", j+1);
      }
    }
  }
}

static void cover_set(CoverNode* cn, int line) {
  // fprintf(stderr, "Adding line %d for [%s]\n", line, cn->file);
  if (cn->bmax < line) {
    cn->bmax = line;
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
  if (! BIT_IS_ON(cn->lines, line)) {
    ++cn->ulen;
    BIT_TURN_ON(cn->lines, line);
  }
}
