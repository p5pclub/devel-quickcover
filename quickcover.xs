#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <stdio.h>
#include <time.h>
#include "glog.h"
#include "cover.h"
#include "util.h"

#define QC_DIRECTORY "/tmp"
#define QC_PREFIX    "QC"
#define QC_EXTENSION ".txt"


/* FUNCTIONS RELATED TO COVER DATA MANAGEMENT */

static void qc_init(void);
static void qc_term(pTHX);
static void qc_dump(pTHX);
static void qc_dump_hash(pTHX_ HV* hash);


static CoverList* cover = 0;
static HV* global_args = 0;
static HV* local_args = 0;
static int qc_inited = 0;

static void qc_init(void)
{
  if (qc_inited) {
    GLOG(("qc_init: already initialised"));
    return;
  }

  qc_inited = 1;
}

static void qc_term(pTHX)
{
  if (!qc_inited) {
    GLOG(("qc_term: not initialised"));
    return;
  }

  qc_dump(aTHX);
}

static void qc_dump(pTHX)
{
  static int count = 0;
  static time_t last = 0;

  time_t t = time(0);
  FILE* fp = 0;
  char base[1024];
  char tmp[1024];
  char txt[1024];
  struct tm now;

  if (!cover) {
    GLOG(("qc_dump: no cover data"));
    return;
  }

  /*
   * If current time is different from last time (seconds resolution), reset
   * file suffix counter to zero.
   */
  if (last != t) {
    last = t;
    count = 0;
  }

  /*
   * Get detailed current time:
   */
  localtime_r(&t, &now);

  /*
   * We generate the information on a file with the following structure:
   *
   *   dir/prefix_YYYYMMDD_hhmmss_pid_NNNNN.txt
   *
   * where NNNNN is a suffix counter to allow for more than one file in a
   * single second interval.
   */
  sprintf(base, "%s_%04d%02d%02d_%02d%02d%02d_%ld_%05d",
          QC_PREFIX,
          now.tm_year + 1900, now.tm_mon + 1, now.tm_mday,
          now.tm_hour, now.tm_min, now.tm_sec,
          (long) getpid(),
          count++);

  /*
   * We generate the information on a file with a prepended dot.  Once we are
   * done, we atomically rename it and get rid of the dot.  This way, any job
   * polling for new files will not find any half-done work.
   */
  sprintf(tmp, "%s/.%s%s", QC_DIRECTORY, base, QC_EXTENSION);
  sprintf(txt, "%s/%s%s" , QC_DIRECTORY, base, QC_EXTENSION);
  GLOG(("qc_dump: dumping cover data [%p] to file [%s]", cover, txt));
  fp = fopen(tmp, "w");
  if (!fp) {
    GLOG(("qc_dump: could not create dump file [%s]", tmp));
  } else {
    qc_dump_hash(aTHX_ global_args);
    qc_dump_hash(aTHX_ local_args);
    local_args = 0;

    cover_dump(cover, fp, &now);
    fclose(fp);
    rename(tmp, txt);
  }

  GLOG(("qc_dump: deleting cover data [%p]", cover));
  cover_destroy(cover);
  cover = 0;
}

static void qc_dump_hash(pTHX_ HV* hash)
{
  dump_hash(aTHX_ hash, stderr);
  fprintf(stderr, "\n");
}

/* FUNCTIONS RELATED TO PERL */

static void pl_init(pTHX);
static void pl_term(pTHX_ void* arg);
static OP* pl_opnext(pTHX);

static Perl_ppaddr_t ons_orig = 0;
static int pl_inited = 0;

static void pl_init(pTHX)
{
  if (pl_inited) {
    GLOG(("pl_init: already initialised"));
    return;
  }

  pl_inited = 1;
  if (!ons_orig) {
    /* This is only done once EVER */
    ons_orig = PL_ppaddr[OP_NEXTSTATE];
    GLOG(("pl_init: op next is [%p]", ons_orig));

    Perl_call_atexit(aTHX_ pl_term, 0);
    GLOG(("pl_init: registered atexit cleanup [%p]", pl_term));
  }

  PL_ppaddr[OP_NEXTSTATE] = pl_opnext;
  GLOG(("pl_init: op next changed to [%p]", pl_opnext));
}

static void pl_term(pTHX_ void* arg)
{
  if (!pl_inited) {
    GLOG(("pl_term: not initialised"));
    return;
  }

  PL_ppaddr[OP_NEXTSTATE] = ons_orig;
  GLOG(("pl_term: op next reset to [%p]", ons_orig));
  pl_inited = 0;

  qc_dump(aTHX);
}

static OP* pl_opnext(pTHX)
{
  OP* ret = 0;

  /* Restore original PP function for speed, already tracked this location. */
  PL_op->op_ppaddr = ons_orig;

  /* Call original PP function */
  ret = ons_orig(aTHX);

  /* If necessary, create cover data repository */
  if (!cover) {
    cover = cover_create();
    GLOG(("pl_opnext: created cover data [%p]", cover));
  }

  /* Now do our own nefarious tracking... */
  cover_add(cover, CopFILE(PL_curcop), CopLINE(PL_curcop));

  /*
   * If you wish to exercise memory and dumping multiple files, uncomment this
   * line.
   */
  /* qc_dump(aTHX); */

  /* Return whatever we got from original PP function */
  return ret;
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

void
start(...)
  PREINIT:
    SV* a0 = 0;
  CODE:
    GLOG(("@@@ start(), items %d", items));
    if (items > 0) {
      GLOG(("Items > 0 : %d", items));
      a0 = ST(0);
      if (SvOK(a0) && SvROK(a0) && SvTYPE(SvRV(a0)) == SVt_PVHV) {
        global_args = (HV*) SvREFCNT_inc(SvRV(a0));
        GLOG(("Got global args %p", global_args));
        qc_dump_hash(aTHX_ global_args);
      }
    }
    pl_init(aTHX);
    qc_init();

void
dump(...)
  PREINIT:
    SV* a0 = 0;
  CODE:
    GLOG(("@@@ dump()"));
    if (items > 0) {
      a0 = ST(1);
      if (SvOK(a0) && SvROK(a0) && SvTYPE(SvRV(a0)) == SVt_PVHV) {
        local_args = (HV*) SvRV(a0);
        GLOG(("Got local args %p", local_args));
        qc_dump_hash(aTHX_ local_args);
      }
    }
    qc_term(aTHX);
