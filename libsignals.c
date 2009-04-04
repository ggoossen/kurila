
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_signals_handler);
XS(XS_signals_set_handler);
XS(XS_signals_supported);

void
Perl_boot_core_signals(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    /* Make it findable via fetchmethod */
    newXSproto("signals::handler", XS_signals_handler, file, "$?=$");
    newXS("signals::supported", XS_signals_supported, file);
}

#ifdef HAS_SIGPROCMASK
static void
restore_sigmask(pTHX_ SV *save_sv)
{
    const sigset_t * const ossetp = (const sigset_t *) SvPV_nolen_const( save_sv );
    (void)sigprocmask(SIG_SETMASK, ossetp, NULL);
}
#endif

void
S_signals_set_handler(SV* handlersv, SV* namesv)
{
    I32 i;
    /* Need to be careful with SvREFCNT_dec(), because that can have side
     * effects (due to closures). We must make sure that the new disposition
     * is in place before it is called.
     */
    SV* to_dec = NULL;
    STRLEN len;
    const char *s;
    bool set_to_ignore = FALSE;
    bool set_to_default = FALSE;
#ifdef HAS_SIGPROCMASK
    sigset_t set, save;
    SV* save_sv;
#endif

    if ( SvROK(handlersv) ) {
	if ( SvTYPE(SvRV(handlersv)) != SVt_PVCV )
	    Perl_croak(aTHX_ "signal handler should be a code refernce, 'DEFAULT' or 'IGNORE'");
    } else {
        const char *s = SvOK(handlersv) ? SvPV_const(handlersv, len) : "DEFAULT";
        if ( strEQ(s,"IGNORE") )
	    set_to_ignore = TRUE;
	else if (strEQ(s,"DEFAULT"))
	    set_to_default = TRUE;
	else
            Perl_croak(aTHX_  "signal handler should be a code reference or 'DEFAULT or 'IGNORE'");
    }

    if (!PL_psig_ptr) {
        Newxz(PL_psig_ptr,  SIG_SIZE, SV*);
        Newxz(PL_psig_name, SIG_SIZE, SV*);
        Newxz(PL_psig_pend, SIG_SIZE, int);
    }

    s = SvPV_const(namesv,len);
    i = whichsig(s);        /* ...no, a brick */
    if (i <= 0) {
        Perl_croak(aTHX_ "No such signal: SIG%s", s);
    }
#ifdef HAS_SIGPROCMASK
    /* Avoid having the signal arrive at a bad time, if possible. */
    sigemptyset(&set);
    sigaddset(&set,i);
    sigprocmask(SIG_BLOCK, &set, &save);
    ENTER;
    save_sv = newSVpvn((char *)(&save), sizeof(sigset_t));
    SAVEFREESV(save_sv);
    SAVEDESTRUCTOR_X(restore_sigmask, save_sv);
#endif
    PERL_ASYNC_CHECK();
#if defined(FAKE_PERSISTENT_SIGNAL_HANDLERS) || defined(FAKE_DEFAULT_SIGNAL_HANDLERS)
    if (!PL_sig_handlers_initted) Perl_csighandler_init();
#endif
#ifdef FAKE_PERSISTENT_SIGNAL_HANDLERS
    PL_sig_ignoring[i] = 0;
#endif
#ifdef FAKE_DEFAULT_SIGNAL_HANDLERS
    PL_sig_defaulting[i] = 0;
#endif
    SvREFCNT_dec(PL_psig_name[i]);
    to_dec = PL_psig_ptr[i];
    PL_psig_ptr[i] = NULL;
    PL_psig_name[i] = newSVpvn(s, len);
    SvREADONLY_on(PL_psig_name[i]);

    if (SvROK(handlersv)) {
	PL_psig_ptr[i] = SvREFCNT_inc(SvRV(handlersv));
	(void)rsignal(i, PL_csighandlerp);
#ifdef HAS_SIGPROCMASK
	LEAVE;
#endif
        if(to_dec)
            SvREFCNT_dec(to_dec);
        return;
    }
    if (set_to_ignore) {
#ifdef FAKE_PERSISTENT_SIGNAL_HANDLERS
	PL_sig_ignoring[i] = 1;
	(void)rsignal(i, PL_csighandlerp);
#else
	(void)rsignal(i, (Sighandler_t) SIG_IGN);
#endif
    }
    else {
#ifdef FAKE_DEFAULT_SIGNAL_HANDLERS
	PL_sig_defaulting[i] = 1;
	(void)rsignal(i, PL_csighandlerp);
#else
	(void)rsignal(i, (Sighandler_t) SIG_DFL);
#endif
    }
#ifdef HAS_SIGPROCMASK
    if(i)
        LEAVE;
#endif
    if(to_dec)
        SvREFCNT_dec(to_dec);
}

XS(XS_signals_handler)
{
    dVAR;
    dXSARGS;
    SV* namesv = POPs;
    PERL_UNUSED_ARG(cv);
    assert(items == 1);

    if (PL_op->op_flags & OPf_ASSIGN) {
        SV* handlersv = POPs;
        S_signals_set_handler(handlersv, namesv);
    }

    {
        SV* sv;
        /* Are we fetching a signal entry? */
        const I32 i = whichsig(SvPV_nolen_const(namesv));

        sv = newSV(0);
        mXPUSHs(sv);
        if (i <= 0) {
            Perl_croak(aTHX_ "No such signal: SIG%s", SvPV_nolen_const(namesv));
        }
        if (!PL_psig_ptr) {
            Newxz(PL_psig_ptr,  SIG_SIZE, SV*);
            Newxz(PL_psig_name, SIG_SIZE, SV*);
            Newxz(PL_psig_pend, SIG_SIZE, int);
        }
        if(PL_psig_ptr[i])
            sv_setsv(sv,sv_2mortal(newRV_inc(PL_psig_ptr[i])));
        else {
            Sighandler_t sigstate = rsignal_state(i);
#ifdef FAKE_PERSISTENT_SIGNAL_HANDLERS
            if (PL_sig_handlers_initted && PL_sig_ignoring[i])
                sigstate = SIG_IGN;
#endif
#ifdef FAKE_DEFAULT_SIGNAL_HANDLERS
            if (PL_sig_handlers_initted && PL_sig_defaulting[i])
                sigstate = SIG_DFL;
#endif
            /* cache state so we don't fetch it again */
            if(sigstate == (Sighandler_t) SIG_IGN)
                sv_setpvs(sv,"IGNORE");
            else
                sv_setsv(sv,&PL_sv_undef);
        }
    }
    XSRETURN(1);
}

XS(XS_signals_supported)
{
    dVAR;
    dXSARGS;
    
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: signals::supported(signalname)");

    if ( whichsig(SvPVX_const(POPs)) == -1 )
	XSRETURN_NO;
    else
	XSRETURN_YES;
}
