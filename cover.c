#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "glog.h"
#include "gmem.h"
#include "cover.h"

/* How big will the initial bit set allocation be. */
#define COVER_INITIAL_SIZE 8   /* 8 * CHAR_BIT = 64 bits (lines) */

/* Handle an array of unsigned char as a bit set. */
#define BIT_TURN_ON(data, bit)   data[bit/CHAR_BIT] |=  (1 << (bit%CHAR_BIT))
#define BIT_TURN_OFF(data, bit)  data[bit/CHAR_BIT] &= ~(1 << (bit%CHAR_BIT))
#define BIT_IS_ON(data, bit)    (data[bit/CHAR_BIT] &   (1 << (bit%CHAR_BIT)))

/* Line tags in generated dump. */
#define COVER_TAG_SUMMARY   0
#define COVER_TAG_FILE_INFO 1
#define COVER_TAG_LINE_INFO 2

/* Add a line to a given CoverNode; grow its bit set if necessary. */
static void cover_node_set_line(CoverNode* node, int line);

CoverList* cover_create(void) {
  CoverList* cover;
  GMEM_NEW(cover, CoverList*, sizeof(CoverList));
  cover->head = 0;
  cover->size = 0;
  return cover;
}

void cover_destroy(CoverList** cover) {
  CoverNode* node = 0;

  assert(cover);
  if (!*cover)
      return;

  for (node = (*cover)->head; node != 0; ) {
    CoverNode* tmp = node;
    GLOG(("Destroying set for [%s], %d/%d elements", node->file, node->bcnt, node->alen*CHAR_BIT));
    node = node->next;
    GLOG(("Destroying string [%s]", tmp->file));
    GMEM_DELSTR(tmp->file, -1);
    GLOG(("Destroying array [%p] with %d elements", tmp->lines, tmp->alen));
    GMEM_DELARR(tmp->lines, unsigned char*, tmp->alen, sizeof(unsigned char*));
    GLOG(("Destroying node [%p]", tmp));
    GMEM_DEL(tmp, CoverNode*, sizeof(CoverNode));
  }
  GLOG(("Destroying cover [%p]", *cover));
  GMEM_DEL(*cover, CoverList*, sizeof(CoverList));
}

CoverNode* cover_add(CoverList* cover, const char* file, int line) {
  CoverNode* node = 0;

  assert(cover);

  for (node = cover->head; node != 0; node = node->next) {
    if (strcmp(node->file, file) == 0) {
      break;
    }
  }
  if (node == 0) {
    GMEM_NEW(node, CoverNode*, sizeof(CoverNode));
    /* TODO: normalise name first? ./foo.pl, foo.pl, ../bar/foo.pl, etc. */
    int l = 0;
    GMEM_NEWSTR(node->file, file, -1, l);
    node->lines = 0;
    node->alen = node->bcnt = node->bmax = 0;
    node->next = cover->head;
    cover->head = node;
    ++cover->size;
    GLOG(("Adding set for [%s]", node->file));
  }
  cover_node_set_line(node, line);
  return node;
}


void cover_dump(CoverList* cover, FILE* fp) {
  CoverNode* node = 0;
  int ncount = 0;

  /*
   * We output the cover data as elements in a JSON hash
   * that must be opened / closed outside this routine.
   */
  fprintf(fp, "\"files\":{");
  for (node = cover->head; node != 0; node = node->next) {
    int j = 0;
    int lcount = 0;

    if (ncount++) {
      fprintf(fp, ",");
    }
    fprintf(fp, "\"%s\":{",
            node->file);
    for (j = 0; j < node->bmax; ++j) {
      if (BIT_IS_ON(node->lines, j)) {
        /* TODO: maybe output more than one line in each line with type 2? */
        if (lcount++) {
          fprintf(fp, ",");
        }
        fprintf(fp, "\"%d\":%d", j+1, 1);
      }
    }
    fprintf(fp, "}");
  }
  fprintf(fp, "}");
}

static void cover_node_set_line(CoverNode* node, int line) {
  /* keep track of largest line seen so far */
  if (node->bmax < line) {
    node->bmax = line;
  }

  --line; /* store line numbers zero-based */

  /* maybe we need to grow the bit set? */
  int needed = line / CHAR_BIT + 1;
  if (node->alen < needed) {
    /* start at COVER_INITIAL_SIZE, then duplicate the size, until we have */
    /* enough room */
    int size = node->alen ? node->alen : COVER_INITIAL_SIZE;
    while (size < needed) {
      size *= 2;
    }

    GLOG(("Growing map for [%s] from %d to %d", node->file, node->alen, size));

    /* realloc will grow the data and keep all current values... */
    GMEM_REALLOC(node->lines, unsigned char*, node->alen * sizeof(unsigned char*), size * sizeof(unsigned char*));

    /* ... but it will not initialise the new space to 0. */
    memset(node->lines + node->alen, 0, size - node->alen);

    /* we are bigger now */
    node->alen = size;
  }

  /* if the line was not already registered, do so and keep track of how many */
  /* lines we have seen so far */
  if (! BIT_IS_ON(node->lines, line)) {
    GLOG(("Adding line %d for [%s]", line, node->file));
    ++node->bcnt;
    BIT_TURN_ON(node->lines, line);
  }
}
