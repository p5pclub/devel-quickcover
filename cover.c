#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cover.h"

// How big will the initial bit set allocation be; 8 * CHAR_BIT = 64 bits.
#define COVER_INITIAL_SIZE 8

// Handle an array of unsigned char as a bit set.
#define BIT_TURN_ON(data, bit)   data[bit/CHAR_BIT] |=  (1 << (bit%CHAR_BIT))
#define BIT_TURN_OFF(data, bit)  data[bit/CHAR_BIT] &= ~(1 << (bit%CHAR_BIT))
#define BIT_IS_ON(data, bit)    (data[bit/CHAR_BIT] &   (1 << (bit%CHAR_BIT)))

// Add a line to a given CoverNode; grow its bit set if necessary.
static void cover_set(CoverNode* node, int line);

CoverList* cover_create(void) {
  CoverList* cover = (CoverList*) malloc(sizeof(CoverList));
  cover->head = 0;
  cover->size = 0;
  return cover;
}

void cover_destroy(CoverList* cover) {
  if (!cover) {
    return;
  }

  for (CoverNode* node = cover->head; node != 0; ) {
    CoverNode* tmp = node;
    // fprintf(stderr, "Destroying set for [%s], %d/%d elements\n", node->file, node->bmax, node->alen*CHAR_BIT);
    node = node->next;
    free(tmp->file);
    free(tmp->lines);
    free(tmp);
  }
  free(cover);
}

CoverNode* cover_add(CoverList* cover, const char* file, int line) {
  CoverNode* node = 0;
  for (node = cover->head; node != 0; node = node->next) {
    if (strcmp(node->file, file) == 0) {
      break;
    }
  }
  if (node == 0) {
    node = (CoverNode*) malloc(sizeof(CoverNode));
    // TODO: normalise name first? ./foo.pl, foo.pl, ../bar/foo.pl, etc.
    node->file = strdup(file);
    node->lines = 0;
    node->alen = node->ulen = node->bmax = 0;
    node->next = cover->head;
    cover->head = node;
    ++cover->size;
    // fprintf(stderr, "Adding set for [%s]\n", node->file);
  }
  cover_set(node, line);
  return node;
}

void cover_dump(CoverList* cover, FILE* fp, struct tm* stamp) {
  struct tm now;
  if (stamp == 0) {
    time_t t = time(0);
    stamp = localtime_r(&t, &now);
  }
  fprintf(fp, "# These are comments. Each line block has the following fields:\n");
  fprintf(fp, "#\n");
  fprintf(fp, "# 0 number_of_files year month day hour minute second\n");
  fprintf(fp, "# 1 number_of_lines file_name\n");
  fprintf(fp, "# 2 line_covered\n");
  fprintf(fp, "# --------------\n");
  fprintf(fp, "0 %d %d %d %d %d %d %d\n",
          cover->size,
          stamp->tm_year + 1900, stamp->tm_mon + 1, stamp->tm_mday,
          stamp->tm_hour, stamp->tm_min, stamp->tm_sec);
  for (CoverNode* node = cover->head; node != 0; node = node->next) {
    fprintf(fp, "1 %d %s\n", node->ulen, node->file);
    for (int j = 0; j < node->bmax; ++j) {
      if (BIT_IS_ON(node->lines, j)) {
        fprintf(fp, "2 %d\n", j+1);
      }
    }
  }
}

static void cover_set(CoverNode* node, int line) {
  // fprintf(stderr, "Adding line %d for [%s]\n", line, node->file);

  // keep track of largest line seen so far
  if (node->bmax < line) {
    node->bmax = line;
  }

  --line; // store line numbers zero-based

  // maybe we need to grow the bit set?
  int needed = line / CHAR_BIT + 1;
  if (node->alen < needed) {
    // start at COVER_INITIAL_SIZE, then duplicate the size, until we have
    // enough room
    int size = node->alen ? node->alen : COVER_INITIAL_SIZE;
    while (size < needed) {
      size *= 2;
    }

    // fprintf(stderr, "Growing map for [%s] from %d to %d\n", node->file, node->alen, size);

    // realloc will grow the data and keep all current values...
    node->lines = realloc(node->lines, size);

    // ... but it will not initialise the new space to 0.
    memset(node->lines + node->alen, 0, size - node->alen);

    // we are bigger now
    node->alen = size;
  }

  // if the line was not already register, do so and keep track of how many
  // lines we have seen so far
  if (! BIT_IS_ON(node->lines, line)) {
    ++node->ulen;
    BIT_TURN_ON(node->lines, line);
  }
}
