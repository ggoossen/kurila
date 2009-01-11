
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

XS(XS_env_set_var)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 2)
	Perl_croak(aTHX_ "Usage: env::set_var(key, value)");
    {
        SV* value = sv_mortalcopy(POPs);
        SV* key = POPs;
        const char* ptr;
        STRLEN klen;
        const char* s = NULL;
        STRLEN len;

        ptr = SvPV_const(key, klen);
        
        if ( SvOK(value) ) {
            s = SvPV_const(value, len);
        }

        my_setenv(ptr, s);

#if !defined(OS2) && !defined(AMIGAOS) && !defined(WIN32) && !defined(MSDOS)
			    /* And you'll never guess what the dog had */
			    /*   in its mouth... */
        if (PL_tainting) {
            MAGIC * mg = NULL;
            if (SvTYPE(value) >= SVt_PVMG && SvMAGIC(value)) {
                mg = mg_find(value, PERL_MAGIC_taint);
            }
            if ( ! mg ) {
                sv_magic(value, NULL, PERL_MAGIC_taint, NULL, 0);
                SvTAINTED_off(value);
                mg = mg_find(value, PERL_MAGIC_taint);
            }
            MgTAINTEDDIR_off(mg);
#ifdef VMS
            if (s && klen == 8 && strEQ(ptr, "DCL$PATH")) {
                char pathbuf[256], eltbuf[256], *cp, *elt;
                Stat_t sbuf;
                int i = 0, j = 0;

                my_strlcpy(eltbuf, s, sizeof(eltbuf));
                elt = eltbuf;
                do {          /* DCL$PATH may be a search list */
                    while (1) {   /* as may dev portion of any element */
                        if ( ((cp = strchr(elt,'[')) || (cp = strchr(elt,'<'))) ) {
                            if ( *(cp+1) == '.' || *(cp+1) == '-' ||
                                cando_by_name(S_IWUSR,0,elt) ) {
                                MgTAINTEDDIR_on(mg);
                                return 0;
                            }
                        }
                        if ((cp = strchr(elt, ':')) != NULL)
                            *cp = '\0';
                        if (my_trnlnm(elt, eltbuf, j++))
                            elt = eltbuf;
                        else
                            break;
                    }
                    j = 0;
                } while (my_trnlnm(s, pathbuf, i++) && (elt = pathbuf));
            }
#endif /* VMS */
            if (s && klen == 4 && strEQ(ptr,"PATH")) {
                const char * const strend = s + len;
                
                while (s < strend) {
                    char tmpbuf[256];
                    Stat_t st;
                    I32 i;
#ifdef VMS  /* Hmm.  How do we get $Config{path_sep} from C? */
                    const char path_sep = '|';
#else
                    const char path_sep = ':';
#endif
                    s = delimcpy(tmpbuf, tmpbuf + sizeof tmpbuf,
                        s, strend, path_sep, &i);
                    s++;
                    if (i >= (I32)sizeof tmpbuf   /* too long -- assume the worst */
#ifdef VMS
                        || !strchr(tmpbuf, ':') /* no colon thus no device name -- assume relative path */
#else
                        || *tmpbuf != '/'       /* no starting slash -- assume relative path */
#endif
                        || (PerlLIO_stat(tmpbuf, &st) == 0 && (st.st_mode & 2)) ) {
                        MgTAINTEDDIR_on(mg);
                    }
                }
            }
        }
#endif /* neither OS2 nor AMIGAOS nor WIN32 nor MSDOS */

        if (SvOK(value)) {
            hv_store_ent(PL_envhv, key, SvREFCNT_inc(value), 0);
        }
        else {
            (void)hv_delete_ent(PL_envhv, key, G_DISCARD, 0);
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
        HV* hv = PL_envhv;
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
