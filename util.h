#ifndef UTIL_H_
#define UTIL_H_

/*
 * A bunch of helper functions.
 */

#include "EXTERN.h"
#include "perl.h"

/* Needed for FILE declaration. */
#include <stdio.h>

void dump_value(pTHX_ SV* val, FILE* fp);
void dump_hash(pTHX_ HV* hash, FILE* fp);
void dump_array(pTHX_ AV* array, FILE* fp);

#endif
