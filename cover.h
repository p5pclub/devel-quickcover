#ifndef COVER_H_
#define COVER_H_

#include <stdio.h>

typedef struct CoverNode {
  char* file;
  unsigned char* lines;
  unsigned short alen;
  unsigned short ulen;
  struct CoverNode* next;
} CoverNode;

typedef struct CoverList {
  CoverNode* head;
  unsigned int size;
} CoverList;

CoverList* cover_create(void);
void cover_destroy(CoverList* cover);
CoverNode* cover_add(CoverList* cover, const char* file, int line);
void cover_dump(CoverList* cover, FILE* fp);

#endif
