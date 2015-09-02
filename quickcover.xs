#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

static void add_line(const char* file, int line) {
  fprintf(stderr, "@@@ add_line [%s] [%d]\n", file, line);
}


static Perl_ppaddr_t ons_orig = 0;

static OP* ons_ccov(pTHX) {
  OP* orig = ons_orig(my_perl);
  const char* file = CopFILE(PL_curcop);
  const line_t line = CopLINE(PL_curcop);
  add_line(file, line);
  return orig;
}

static void term(pTHX, void* arg) {
  fprintf(stderr, "cleaning up\n");
}

static void init(pTHX) {
  fprintf(stderr, "initialising\n");

  ons_orig = PL_ppaddr[OP_NEXTSTATE];
  fprintf(stderr, "current op is [%p]\n", ons_orig);

  PL_ppaddr[OP_NEXTSTATE] = ons_ccov;
  fprintf(stderr, "op changed to [%p]\n", ons_ccov);

  Perl_call_atexit(aTHX, term, 0);
  fprintf(stderr, "registered cleanup [%p] at_exit\n", term);
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

void
import(SV* pclass, ... )
  PREINIT:

  CODE:
    const char* cclass = SvPV_nolen(pclass);
    fprintf(stderr, "@@@ import() for [%s]\n", cclass);

    init(aTHX);
