#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <stdio.h>
#include <time.h>
#include "glog.h"
#include "cover.h"

#define QC_DIRECTORY "/tmp"
#define QC_PREFIX    "QC"
#define QC_EXTENSION ".txt"

#ifndef __GNUC__
#  define  __attribute__(x)
#endif

static CoverList* cover = 0;
static Perl_ppaddr_t ons_orig = 0;

static OP* ons_quickcover(pTHX) {
  /* Restore original PP function for speed, already tracked this location. */
  PL_op->op_ppaddr = ons_orig;

  /* Call original PP function */
  OP* ret = ons_orig(aTHX);

  /* Now do our own nefarious tracking... */
  cover_add(cover, CopFILE(PL_curcop), CopLINE(PL_curcop));

  /* Return whatever we got from original PP function */
  return ret;
}

static void qc_dump(void) {
  GLOG(("qc_dump: dumping cover [%p]", cover));
  time_t t = time(0);
  struct tm now;
  localtime_r(&t, &now);

  /*
   * We generate the information on a file with the following structure:
   *
   *   dir/prefix_YYYYMMDD_hhmmss_pid.txt
   */
  char base[1024];
  sprintf(base, "%s_%04d%02d%02d_%02d%02d%02d_%ld",
          QC_PREFIX,
          now.tm_year + 1900, now.tm_mon + 1, now.tm_mday,
          now.tm_hour, now.tm_min, now.tm_sec,
          (long) getpid());

  /*
   * We generate the information on a file with a prepended dot.  Once we are
   * done, we atomically rename it and get rid of the dot.  This way, any job
   * polling for new files will not find any half-done work.
   */
  char tmp[1024];
  char txt[1024];
  sprintf(tmp, "%s/.%s%s", QC_DIRECTORY, base, QC_EXTENSION);
  sprintf(txt, "%s/%s%s" , QC_DIRECTORY, base, QC_EXTENSION);
  FILE* fp = fopen(tmp, "w");
  if (!fp) {
    GLOG(("qc_dump: could not create dump file [%s]", tmp));
  } else {
    cover_dump(cover, fp, &now);
    fclose(fp);
    rename(tmp, txt);
  }

  GLOG(("qc_dump: deleting cover [%p]", cover));
  cover_destroy(cover);
  cover = 0;
}

static void term(pTHX_ void* arg) {
  if (! cover) {
    GLOG(("term: not initialised"));
    return;
  }

  GLOG(("term: called from atexit"));
  qc_dump();
}

static void init(pTHX) {
  if (cover) {
    GLOG(("init: already initialised"));
    return;
  }

  GLOG(("init: initialising"));

  cover = cover_create();
  GLOG(("init: created cover [%p]", cover));

  ons_orig = PL_ppaddr[OP_NEXTSTATE];
  GLOG(("init: current op is [%p]", ons_orig));

  PL_ppaddr[OP_NEXTSTATE] = ons_quickcover;
  GLOG(("init: op changed to [%p]", ons_quickcover));

  Perl_call_atexit(aTHX_ term, 0);
  GLOG(("init: registered cleanup [%p] at_exit", term));
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

void
import(SV* pclass)
  CODE:
    __attribute__((unused)) const char* cclass = SvPV_nolen(pclass);
    GLOG(("@@@ import() for [%s]", cclass));
    init(aTHX);

void
dump()
  CODE:
    GLOG(("@@@ dump()"));
    qc_dump();
