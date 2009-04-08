
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

/*
  TODO:
  #ifdef ENV_IS_CASELESS
*/

XS(XS_env_keys);
XS(XS_env_var);
XS(XS_env_set_var);

void
Perl_boot_core_env(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    /* Make it findable via fetchmethod */
    newXSproto("env::var", XS_env_var, file, "$?=$");
    newXS("env::keys", XS_env_keys, file);
}

XS(XS_env_var)
{
    dVAR;
    dXSARGS;
    SV* key;
    PERL_UNUSED_ARG(cv);
    assert(items == 1);

    key = POPs;

    if (PL_op->op_flags & OPf_ASSIGN) {
        SV* valuesv = sv_mortalcopy(POPs);

        const char* ptr;
        STRLEN klen;
        const char* s = NULL;
        STRLEN len;

        ptr = SvPV_const(key, klen);
        
        if ( SvOK(valuesv) ) {
            s = SvPV_const(valuesv, len);
        }

        my_setenv(ptr, s);

        if (SvOK(valuesv)) {
            hv_store_ent(PL_envhv, key, SvREFCNT_inc(valuesv), 0);
        }
        else {
            (void)hv_delete_ent(PL_envhv, key, G_DISCARD, 0);
        }
    }

    {
        SV* sv;

        HE* he = hv_fetch_ent(PL_envhv, key, FALSE, 0);
        if (he) { 
	    sv = newSVsv(HeVAL(he));
        }
        else {
            sv = newSVsv(&PL_sv_undef);
        }
        mXPUSHs(sv);
    }
    XSRETURN(1);
}

XS(XS_env_keys)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 0)
	Perl_croak(aTHX_ "Usage: env::keys()");
    {
        HV* hv = PL_envhv;
        register HE *entry;
        AV* res = newAV();
        mXPUSHs(avTsv(res));

        (void)hv_iterinit(hv);	/* always reset iterator regardless */
        while ((entry = hv_iternext(hv))) {
	    SV* const sv = hv_iterkeysv(entry);
	    av_push(res, newSVsv(sv));
        }
    }
    XSRETURN(1);
}
