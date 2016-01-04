#define PERL_NO_GET_CONTEXT     /* we want efficiency */

#include "util.h"

#define CHECK_SPACE(buf, needed) \
    if ((buf->len - buf->pos) < (needed)) { \
        croak("Fuck"); \
        return; \
    }

void dump_value(pTHX_ SV* val, Buffer* buf)
{
  if (!val) {
    return;
  }

  if (SvIOK(val)) {
    CHECK_SPACE(buf, 10);
    buf->pos += sprintf(buf->data + buf->pos, "%ld", (long) SvIV(val));
  } else if (SvNOK(val)) {
    CHECK_SPACE(buf, 20);
    buf->pos += sprintf(buf->data + buf->pos, "%lf", (double) SvNV(val));
  } else if (SvPOK(val)) {
    STRLEN len;
    char* str = SvPV(val, len);
    CHECK_SPACE(buf, len+2);
    buf->pos += sprintf(buf->data + buf->pos, "\"%*.*s\"", (int) len, (int) len, str);
  } else if (SvROK(val)) {
    SV* rv = SvRV(val);
    if (SvTYPE(rv) == SVt_PVAV) {
      dump_array(aTHX_ (AV*) rv, buf);
    } else if (SvTYPE(rv) == SVt_PVHV) {
      dump_hash(aTHX_ (HV*) rv, buf);
    }
  }
}

void dump_hash(pTHX_ HV* hash, Buffer* buf)
{
  int count = 0;
  if (!hash) {
    return;
  }

  CHECK_SPACE(buf, 1);
  buf->data[buf->pos++] = '{';

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
      CHECK_SPACE(buf, 1);
      buf->data[buf->pos++] = ',';
    }

    key = hv_iterkey(entry, &klen);
    val = hv_iterval(hash, entry);

    CHECK_SPACE(buf, klen+2);
    buf->pos += sprintf(buf->data + buf->pos, "\"%*.*s\":", (int) klen, (int) klen, key);
    dump_value(aTHX_ val, buf);
  }

  CHECK_SPACE(buf, 1);
  buf->data[buf->pos++] = '}';
}

void dump_array(pTHX_ AV* array, Buffer* buf)
{
  SSize_t top = 0;
  int j = 0;
  if (!array) {
    return;
  }

  CHECK_SPACE(buf, 1);
  buf->data[buf->pos++] = '[';

  top = av_len(array);
  for (j = 0; j <= top; ++j) {
    SV** elem = av_fetch(array, j, 0);
    if (j) {
      CHECK_SPACE(buf, 1);
      buf->data[buf->pos++] = ',';
    }
    dump_value(aTHX_ *elem, buf);
  }

  CHECK_SPACE(buf, 1);
  buf->data[buf->pos++] = ']';
}
