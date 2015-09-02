#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "cover.h"

static CoverList* cover = 0;

static void add_line(const char* file, int line) {
  /* warn("@@@ add_line [%s] [%d]\n", file, line); */
  cover_add(cover, file, line);
}


static Perl_ppaddr_t ons_orig = 0;

static OP* ons_qc(pTHX) {
  /* Restore original PP function for speed since we already tracked this location. */
  PL_op->op_ppaddr = ons_orig;

  /* Call original PP function */
  OP* ret = ons_orig(my_perl);

  /* Now do our own nefarious tracking... */
  const char* file = CopFILE(PL_curcop);
  const line_t line = CopLINE(PL_curcop);
  add_line(file, line);

  /* Return whatever we got from original PP function */
  return ret;
}

static void term(pTHX, void* arg) {
  /* warn("cleaning up\n"); */

  /* warn("dumping cover [%p]\n", cover); */
  cover_dump(cover, stderr);

  /* warn("deleting cover [%p]\n", cover); */
  cover_destroy(cover);
  cover = 0;
}

static void init(pTHX) {
  /* warn("initialising\n"); */

  cover = cover_create();
  /* warn("created cover [%p]\n", cover); */

  ons_orig = PL_ppaddr[OP_NEXTSTATE];
  /* warn("current op is [%p]\n", ons_orig); */

  PL_ppaddr[OP_NEXTSTATE] = ons_qc;
  /* warn("op changed to [%p]\n", ons_qc); */

  Perl_call_atexit(aTHX, term, 0);
  /* warn("registered cleanup [%p] at_exit\n", term); */
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

void
import(SV* pclass, ... )
  PREINIT:

  CODE:
    /* const char* cclass = SvPV_nolen(pclass); */
    /* warn("@@@ import() for [%s]\n", cclass); */

    init(aTHX);
