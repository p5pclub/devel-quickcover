#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "glog.h"
#include "gmem.h"
#include "cover.h"
#include "util.h"

#define QC_PREFIX    "QC"
#define QC_EXTENSION ".txt"

#define QC_PACKAGE                 "Devel::QuickCover"
#define QC_CONFIG_VAR              QC_PACKAGE "::CONFIG"

#define QC_CONFIG_OUTPUTDIR        "output_directory"
#define QC_CONFIG_METADATA         "metadata"

#define MAX_OUTPUTDIR_LENGTH       1024
#define MAX_METADATA_LENGTH        1024

static Perl_ppaddr_t nextstate_orig = 0;
static CoverList* cover = 0;
static int enabled = 0;
static char output_dir[MAX_OUTPUTDIR_LENGTH];
static char metadata[MAX_METADATA_LENGTH];

static void qc_init(void);
static void qc_fini(void);
static void qc_install(pTHX);
static OP*  qc_nextstate(pTHX);
static void qc_dump(CoverList* cover);

static void save_stuff(pTHX);
static void save_output_directory(pTHX);
static void save_metadata(pTHX);

static void qc_init(void)
{
    atexit(qc_fini);

    gmem_init();
    strcpy(output_dir, "/tmp");
    metadata[0] = '\0';
}

static void qc_fini(void)
{
    if (cover) {
        qc_dump(cover);
        cover_destroy(cover);
        cover = 0;
    }

    gmem_fini();
}

static void qc_install(pTHX)
{
    if (PL_ppaddr[OP_NEXTSTATE] == qc_nextstate) {
        die("%s: internal error, exiting: qc_install called again", QC_PACKAGE);
    }

    nextstate_orig = PL_ppaddr[OP_NEXTSTATE];
    PL_ppaddr[OP_NEXTSTATE] = qc_nextstate;

    GLOG(("qc_install: nextstate_orig is [%p]", nextstate_orig));
    GLOG(("qc_install:   qc_nextstate is [%p]", qc_nextstate));
}

static OP* qc_nextstate(pTHX) {
    OP* ret = nextstate_orig(aTHX);

    if (enabled) {
        PL_op->op_ppaddr = nextstate_orig;
        if (!cover) {
            cover = cover_create();
            GLOG(("qc_nextstate: created cover data [%p]", cover));
        }
        /* Now do our own nefarious tracking... */
        cover_add(cover, CopFILE(PL_curcop), CopLINE(PL_curcop));
    }

    return ret;
}

static void qc_dump(CoverList* cover)
{
    static int count = 0;
    static time_t last = 0;

    time_t t = 0;
    FILE* fp = 0;
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
     *   output_dir/prefix_YYYYMMDD_hhmmss_pid_NNNNN.txt
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
    sprintf(tmp, "%s/.%s%s", output_dir, base, QC_EXTENSION);
    sprintf(txt, "%s/%s%s" , output_dir, base, QC_EXTENSION);

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

        fprintf(fp, "\"metadata\":%s,", metadata);
        cover_dump(cover, fp);

        fprintf(fp, "}\n");
        fclose(fp);
        rename(tmp, txt);
    }
}

static void save_stuff(pTHX)
{
    save_output_directory(aTHX);
    save_metadata(aTHX);

}

static void save_output_directory(pTHX)
{
    HV* qc_config = 0;
    SV** val = 0;
    STRLEN len = 0;
    const char* str;

    qc_config = get_hv(QC_CONFIG_VAR, 0);
    if (!qc_config) {
        die("%s: Internal error, exiting: %s must exist",
            QC_PACKAGE, QC_CONFIG_VAR);
    }
    val = hv_fetch(qc_config, QC_CONFIG_OUTPUTDIR,
                   sizeof(QC_CONFIG_OUTPUTDIR) - 1, 0);
    if (!SvUTF8(*val)) {
        sv_utf8_upgrade(*val);
    }
    str = SvPV_const(*val, len);
    if (len >= MAX_OUTPUTDIR_LENGTH) {
        die("%s: Internal error, exiting: %s length %lu is greater than max %lu",
            QC_PACKAGE, QC_CONFIG_OUTPUTDIR,
            (unsigned long) len, (unsigned long) MAX_OUTPUTDIR_LENGTH);
    }
    memcpy(output_dir, str, len + 1);
}

static void save_metadata(pTHX)
{
    HV* qc_config = 0;
    SV** val = 0;
    HV* hv;
    Buffer buffer;

    qc_config = get_hv(QC_CONFIG_VAR, 0);
    if (!qc_config) {
        die("%s: Internal error, exiting: %s must exist",
            QC_PACKAGE, QC_CONFIG_VAR);
    }
    val = hv_fetch(qc_config, QC_CONFIG_METADATA,
                   sizeof(QC_CONFIG_METADATA) - 1, 0);
    if (!SvROK(*val) || SvTYPE(SvRV(*val)) != SVt_PVHV) {
        die("%s: Internal error, exiting: %s must be a hashref",
            QC_PACKAGE, QC_CONFIG_METADATA);
    }

    hv = (HV*) SvRV(*val);
    buffer.data = metadata;
    buffer.pos = 0;
    buffer.len = MAX_METADATA_LENGTH;
    dump_hash(aTHX_ hv, &buffer);
    metadata[buffer.pos] = '\0';
    GLOG(("Saved metadata [%s]", metadata));
}


MODULE = Devel::QuickCover        PACKAGE = Devel::QuickCover
PROTOTYPES: DISABLE

#################################################################

BOOT:
    GLOG(("@@@ BOOT"));
    qc_install(aTHX);

void
start()
CODE:
    GLOG(("@@@ start()"));
    if (enabled) {
        croak("%s::start() can be called only once.", QC_PACKAGE);
    }
    enabled = 1;
    qc_init();
    save_stuff(aTHX);

void
end()
CODE:
    GLOG(("@@@ end()"));
    if (!enabled) {
        croak("%s::start() must be called before calling %s::end()",
              QC_PACKAGE, QC_PACKAGE);
    }
    save_stuff(aTHX);
    qc_fini();
    enabled = 0;
