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

#ifndef __GNUC__
#  define  __attribute__(x)
#endif

static CoverList* cover = 0;
static Perl_ppaddr_t ons_orig = 0;

static OP* ons_quickcover(pTHX) {
  /* Restore original PP function for speed since we already tracked this location. */
  PL_op->op_ppaddr = ons_orig;

  /* Call original PP function */
  OP* ret = ons_orig(aTHX);

  /* Now do our own nefarious tracking... */
  cover_add(cover, CopFILE(PL_curcop), CopLINE(PL_curcop));

  /* Return whatever we got from original PP function */
  return ret;
}

static void term(pTHX_ void* arg) {
  GLOG(("cleaning up"));

  GLOG(("dumping cover [%p]", cover));
  time_t t = time(0);
  struct tm now;
  localtime_r(&t, &now);

  /*
   * We generate the information on a file with the following structure:
   *
   *   dir/prefix_YYYYMMDD_hhmmss_pid.txt
   */
  char base[1024];
  sprintf(base, "%s/%s_%04d%02d%02d_%02d%02d%02d_%ld",
          QC_DIRECTORY, QC_PREFIX,
          now.tm_year + 1900, now.tm_mon + 1, now.tm_mday,
          now.tm_hour, now.tm_min, now.tm_sec,
          (long) getpid());

  /*
   * We generate the information on a file with a TMP extension.
   * Once we are done, we atomically rename it to a txt extension.
   * This way, any job polling for .txt files will not find any
   * half-done work.
   */
  char tmp[1024];
  char txt[1024];
  sprintf(tmp, "%s.TMP", base);
  sprintf(txt, "%s.txt", base);
  FILE* fp = fopen(tmp, "w");
  if (!fp) {
    GLOG(("Could not create dump file [%s]", name));
  } else {
    cover_dump(cover, fp, &now);
    fclose(fp);
    rename(tmp, txt);
  }

  GLOG(("deleting cover [%p]", cover));
  cover_destroy(cover);
  cover = 0;
}

static void init(pTHX) {
  GLOG(("initialising"));

  cover = cover_create();
  GLOG(("created cover [%p]", cover));

  ons_orig = PL_ppaddr[OP_NEXTSTATE];
  GLOG(("current op is [%p]", ons_orig));

  PL_ppaddr[OP_NEXTSTATE] = ons_quickcover;
  GLOG(("op changed to [%p]", ons_quickcover));

  Perl_call_atexit(aTHX_ term, 0);
  GLOG(("registered cleanup [%p] at_exit", term));
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

void
import(SV* pclass)
  PREINIT:
  CODE:
    __attribute__((unused)) const char* cclass = SvPV_nolen(pclass);
    GLOG(("@@@ import() for [%s]", cclass));

    init(aTHX);
