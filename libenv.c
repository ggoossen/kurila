
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_env_keys);
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
    newXS("env::keys", XS_env_keys, file);
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

        my_setenv(
            SvPV_nolen_const(key),
            SvOK(value) ? SvPV_nolen_const(value) : NULL
            );
        if (SvOK(value)) {
            hv_store_ent(GvHV(PL_envgv), key, newSVsv(value), 0);
        }
        else {
            hv_delete_ent(GvHV(PL_envgv), key, G_DISCARD, 0);
        }
    }
    XSRETURN(0);
}

XS(XS_env_keys)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 0)
	Perl_croak(aTHX_ "Usage: env::keys()");
    {
        HV* hv = GvHV(PL_envgv);
        register HE *entry;
        AV* res = newAV();
        mXPUSHs(AvSv(res));

        (void)hv_iterinit(hv);	/* always reset iterator regardless */
        while ((entry = hv_iternext(hv))) {
	    SV* const sv = hv_iterkeysv(entry);
	    av_push(res, newSVsv(sv));
        }
    }
    XSRETURN(1);
}
