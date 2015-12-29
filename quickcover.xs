#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "glog.h"
#include "cover.h"
#include "util.h"

#define QC_PREFIX    "QC"
#define QC_EXTENSION ".txt"

#define QC_PACKAGE                 "Devel::QuickCover"
#define QC_CONFIG_VAR              QC_PACKAGE "::CONFIG"
#define QC_METADATA_VAR            QC_PACKAGE "::METADATA"

#define QC_CONFIG_OUTPUT_DIR       "output_directory"
#define QC_CONFIG_METADATA         "metadata"

static Perl_ppaddr_t nextstate_orig = 0;
static CoverList* cover = 0;
int enabled = 0;

static void qc_install(pTHX);
static OP*  qc_nextstate(pTHX);
static const char* output_directory(pTHX);
static void dump_metadata(pTHX_ FILE* fp);

static void qc_install(pTHX)
{
    if (PL_ppaddr[OP_NEXTSTATE] == qc_nextstate) {
        die("%s: internal error, exiting: qc_install called again", QC_PACKAGE);
    }

    nextstate_orig = PL_ppaddr[OP_NEXTSTATE];
    PL_ppaddr[OP_NEXTSTATE] = qc_nextstate;

    GLOG(("qc_install: nextstate_orig is [%p]\n"
          "              qc_nextstate is [%p]\n",
          nextstate_orig, qc_nextstate));
}

static OP* qc_nextstate(pTHX) {
    OP* ret = nextstate_orig(aTHX);

    if (enabled) {
        PL_op->op_ppaddr = nextstate_orig;
        if (!cover) {
            cover = cover_create();
            GLOG(("qc_nextstate: created cover data is [%p]", cover));
        }
        /* Now do our own nefarious tracking... */
        cover_add(cover, CopFILE(PL_curcop), CopLINE(PL_curcop));
    }

    return ret;
}

static void qc_dump(pTHX_ CoverList* cover)
{
    static int count = 0;
    static time_t last = 0;

    time_t t = 0;
    FILE* fp = 0;
    const char* dir = 0;
    char base[1024];
    char tmp[1024];
    char txt[1024];
    struct tm now;

    /*
     * If current time is different from last time (seconds
     * resolution), reset file suffix counter to zero.
     */
    t = time(0);
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
    dir = output_directory(aTHX);
    sprintf(tmp, "%s/.%s%s", dir, base, QC_EXTENSION);
    sprintf(txt, "%s/%s%s" , dir, base, QC_EXTENSION);

    GLOG(("qc_dump: dumping cover data [%p] to file [%s]", cover, txt));
    fp = fopen(tmp, "w");
    if (!fp) {
        GLOG(("qc_dump: could not create dump file [%s]", tmp));
    } else {
        fprintf(fp, "{");

        fprintf(fp, "\"date\":\"%04d-%02d-%02d\",",
                now.tm_year + 1900, now.tm_mon + 1, now.tm_mday);
        fprintf(fp, "\"time\":\"%02d:%02d:%02d\",",
                now.tm_hour, now.tm_min, now.tm_sec);

        dump_metadata(aTHX_ fp);

        cover_dump(cover, fp);

        fprintf(fp, "}");
        fclose(fp);
        rename(tmp, txt);
    }
}

static const char* output_directory(pTHX)
{
    HV* qc_config = 0;
    SV** val = 0;
    STRLEN len = 0;

    qc_config = get_hv(QC_CONFIG_VAR, 0);
    if (!qc_config) {
        die("%s: Internal error, exiting: %s must exist",
            QC_PACKAGE, QC_CONFIG_VAR);
    }
    val = hv_fetch(qc_config, QC_CONFIG_OUTPUT_DIR,
                   sizeof(QC_CONFIG_OUTPUT_DIR) - 1, 0);
    if (!SvUTF8(*val)) {
        sv_utf8_upgrade(*val);
    }
    return SvPV_const(*val, len);
}

static void dump_metadata(pTHX_ FILE* fp)
{
    HV* qc_metadata = 0;

    qc_metadata = get_hv(QC_METADATA_VAR, 0);
    if (!qc_metadata) {
        die("%s: Internal error, exiting: %s must exist",
            QC_PACKAGE, QC_METADATA_VAR);
    }

    fprintf(fp, "\"%s\":", QC_CONFIG_METADATA);
    dump_hash(aTHX_ qc_metadata, fp);
    fprintf(fp, ",");
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

BOOT:
    qc_install(aTHX);

void
start()
CODE:
    GLOG(("@@@ start()"));
    if (enabled) {
        croak("%s::start() can be called only once.", QC_PACKAGE);
    }

    enabled = 1;

void
end()
CODE:
    GLOG(("@@@ end()"));
    if (!enabled) {
        croak("%s::start() must be called before calling %s::end()",
              QC_PACKAGE, QC_PACKAGE);
    }

    enabled = 0;
    if (cover) {
    	qc_dump(aTHX_ cover);
    	cover_destroy(&cover);
    }

