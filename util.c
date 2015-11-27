#define PERL_NO_GET_CONTEXT     /* we want efficiency */
/* #include "EXTERN.h" */
/* #include "perl.h" */
/* #include "XSUB.h" */
/* #include "ppport.h" */

#include "util.h"

void dump_value(pTHX_ SV* val, FILE* fp)
{
  if (!val) {
    return;
  }

  if (SvIOK(val)) {
    fprintf(fp, "%ld", (long) SvIV(val));
  } else if (SvNOK(val)) {
    fprintf(fp, "%lf", (double) SvNV(val));
  } else if (SvPOK(val)) {
    fprintf(fp, "%s", SvPV_nolen(val));
  } else if (SvROK(val)) {
    SV* rv = SvRV(val);
    if (SvTYPE(rv) == SVt_PVAV) {
      dump_array(aTHX_ (AV*) rv, fp);
    } else if (SvTYPE(rv) == SVt_PVHV) {
      dump_hash(aTHX_ (HV*) rv, fp);
    }
  }
}

void dump_hash(pTHX_ HV* hash, FILE* fp)
{
  int count = 0;
  if (!hash) {
    return;
  }

  fprintf(fp, "{");
  hv_iterinit(hash);
  while (1) {
    I32 klen = 0;
    char* key = 0;
    SV* val = 0;
    HE* entry = hv_iternext(hash);
    if (!entry) {
      break;
    }

    if (count++) {
      fprintf(fp, ",");
    }
    key = hv_iterkey(entry, &klen);
    val = hv_iterval(hash, entry);
    fprintf(fp, "%*.*s:", (int) klen, (int) klen, key);
    dump_value(aTHX_ val, fp);
  }
  fprintf(fp, "}");
}

void dump_array(pTHX_ AV* array, FILE* fp)
{
  SSize_t top = 0;
  int j = 0;
  if (!array) {
    return;
  }

  fprintf(fp, "[");
  top = av_top_index(array);
  for (j = 0; j <= top; ++j) {
    SV** elem = av_fetch(array, 0, 0);
    if (!j) {
      fprintf(fp, ",");
    }
    dump_value(aTHX_ *elem, fp);
  }
  fprintf(fp, "]");
}
