
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_env_var);
XS(XS_env_set_var);

void
Perl_boot_core_env(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    /* Make it findable via fetchmethod */
    newXS("env::var", XS_env_var, file);
    newXS("env::set_var", XS_env_set_var, file);
}

XS(XS_env_var)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: env::var(name)");
    {
        SV* sv;
        SV* key = POPs;
	unsigned long len;
	const char * const env = Perl_getenv_len(SvPV_nolen_const(key),&len);
	if (env)
	    sv = newSVpvn(env,len);
        else
            sv = newSVsv(&PL_sv_undef);
        SvTAINTED_on(sv);
        mXPUSHs(sv);
    }
    XSRETURN(1);
}

XS(XS_env_set_var)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 2)
	Perl_croak(aTHX_ "Usage: env::set_var(key, value)");
    {
        SV* value = POPs;
        SV* key = POPs;

        my_setenv(SvPVX_const(key), SvPVX_const(value));
    }
    XSRETURN(0);
}
