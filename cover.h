#ifndef COVER_H_
#define COVER_H_

/*
 * Handle a list of file names, and for each of them the set of lines in that
 * file that were actually executed.
 */

/* Needed for FILE declaration. */
#include <stdio.h>

/*
 * We will have one of these per file, stored in a singly linked list.
 */
typedef struct CoverNode {
  char* file;                 /* file name */
  unsigned char* lines;       /* bit set with the "covered lines" */
  unsigned short alen;        /* current length of lines array */
  unsigned short bmax;        /* value of largest bit (line) seen so far */
  unsigned short bcnt;        /* number of different bits (lines) seen so far */
  struct CoverNode* next;     /* next element in list */
} CoverNode;

/*
 * A placeholder for the linked list with file coverage information.
 */
typedef struct CoverList {
  CoverNode* head;            /* head of file list */
  unsigned int size;          /* current size of list */
} CoverList;

/*
 * Create a CoverList object.
 */
CoverList* cover_create(void);

/*
 * Destroy a CoverList object.
 * After freeing the CoverList we assign NULL to cover
 */
void cover_destroy(CoverList** cover);

/*
 * Add a file:line to the CoverList; will create CoverNode for file, if it
 * doesn't already exist.
 */
CoverNode* cover_add(CoverList* cover, const char* file, int line);

/*
 * Dump all data to a given file stream; if stamp is given, use it as the
 * "current timestamp" for the dump.
 */
void cover_dump(CoverList* cover, FILE* fp, struct tm* stamp);


#endif
