#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "bsd_glob.h"

#define MY_CXT_KEY "File::Glob::_guts" XS_VERSION

typedef struct {
    int		x_GLOB_ERROR;
} my_cxt_t;

START_MY_CXT

#include "const-c.inc"

#ifdef WIN32
#define errfunc		NULL
#else
static int
errfunc(const char *foo, int bar) {
  return !(bar == EACCES || bar == ENOENT || bar == ENOTDIR);
}
#endif

MODULE = File::Glob		PACKAGE = File::Glob

BOOT:
{
    MY_CXT_INIT;
}

void
doglob(pattern,...)
    char *pattern
PROTOTYPE: $;$
PREINIT:
    glob_t pglob;
    int i;
    int retval;
    int flags = 0;
    SV *tmp;
    AV *av;
PPCODE:
    {
	dMY_CXT;

	/* allow for optional flags argument */
	if (items > 1) {
	    flags = (int) SvIV(ST(1));
	}

	/* call glob */
	retval = bsd_glob(pattern, flags, errfunc, &pglob);
        MY_CXT.x_GLOB_ERROR = retval;

	/* return any matches found */
        av = (AV*)sv_2mortal((SV*)newAV());
	for (i = 0; i < pglob.gl_pathc; i++) {
	    /* printf("# bsd_glob: %s\n", pglob.gl_pathv[i]); */
	    tmp = newSVpvn(pglob.gl_pathv[i],
			  strlen(pglob.gl_pathv[i]));
            av_push(av, tmp);
	}

	bsd_globfree(&pglob);

	EXTEND(sp, 1);
        PUSHs((SV*)av);
    }

IV
GLOB_ERROR()
PROTOTYPE:
PPCODE:
        {
            	dMY_CXT;

                PUSHs(sv_2mortal(newSViv(MY_CXT.x_GLOB_ERROR)));
        }
                

INCLUDE: const-xs.inc
