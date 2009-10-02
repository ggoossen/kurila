
/* Enter a block. */
PERL_CONTEXT * 
Perl_push_block(pTHX_ U8 t, SV** sp, U8 gimme) {
    PERL_CONTEXT *cx;
    HV *new_dynascope;
    PERL_ARGS_ASSERT_PUSH_BLOCK;
    CXINC;
    cx = &cxstack[cxstack_ix];
    cx->cx_type		= t;
    cx->blk_oldsp		= sp - PL_stack_base;
    cx->blk_oldcop		= PL_curcop;
    cx->blk_oldop		= PL_op;
    cx->blk_oldmarksp	= PL_markstack_ptr - PL_markstack;
    cx->blk_oldscopesp	= PL_scopestack_ix;
    cx->blk_oldpm		= PL_curpm;
    cx->blk_gimme		= gimme;
    cx->blk_dynascope       = PL_dynamicscope;

    new_dynascope = newHV();
    if (PL_dynamicscope)
        (void)hv_stores( new_dynascope, "parent", newRV(PL_dynamicscope) );
    (void)hv_stores( new_dynascope, "onleave", avTsv(newAV()) );
    PL_dynamicscope = hvTsv(new_dynascope);

    DEBUG_l( PerlIO_printf(Perl_debug_log, "Entering block %ld, type %s\n",
            (long)cxstack_ix, PL_block_type[CxTYPE(cx)]); );
    return cx;
}

PERL_CONTEXT * 
Perl_pop_block(pTHX) {
    PERL_CONTEXT * cx;
    SV** onleave_ref = hv_fetchs(svThv(PL_dynamicscope), "onleave", 0);
    if (onleave_ref && SvAVOK(*onleave_ref)) {
        AV* onleave = svTav(*onleave_ref);
        while (av_len(onleave) >= 0) {
            SV* onleave_item = av_pop(onleave);
            PUSHMARK(PL_stack_sp);
            call_sv(onleave_item, G_DISCARD|G_VOID);
        }
    }

    cx = &cxstack[cxstack_ix--];
    PL_curcop	 = cx->blk_oldcop;
    PL_markstack_ptr = PL_markstack + cx->blk_oldmarksp;
    PL_scopestack_ix = cx->blk_oldscopesp;
    SVcpSTEAL(PL_dynamicscope, cx->blk_dynascope);

    DEBUG_l( PerlIO_printf(Perl_debug_log, "Leaving block %ld, type %s\n",
            (long)cxstack_ix+1,PL_block_type[CxTYPE(cx)]) );
    return cx;
}

void Perl_cx_free_eval(pTHX_ PERL_CONTEXT* cx) {
    PERL_ARGS_ASSERT_CX_FREE_EVAL;
    PL_in_eval = CxOLD_IN_EVAL(cx);
    ROOTOPcpNULL(PL_eval_root);
    PL_eval_root = cx->blk_eval.old_eval_root;
    if (cx->blk_eval.old_namesv)
        sv_2mortal(cx->blk_eval.old_namesv);
}

void Perl_push_stack(pTHX_ I32 type, SV*** spp)
{
    SV** sp;
    PERL_SI *next = PL_curstackinfo->si_next;
    PERL_ARGS_ASSERT_PUSH_STACK;

    if (!next) {
        next = new_stackinfo(32, 2048/sizeof(PERL_CONTEXT) - 1);	
        next->si_prev = PL_curstackinfo;			
        PL_curstackinfo->si_next = next;		
    }                                           
    next->si_type = type;			
    next->si_cxix = -1;                 
#ifdef DEBUGGING
    next->olddebug = PL_debug;         
    PL_debug &= ~DEBUG_R_FLAG;        
#endif /* DEBUGGING */
    AvFILLp(next->si_stack) = 0;		
    sp = *spp;
    SWITCHSTACK(PL_curstack,next->si_stack);
    *spp = sp;
    PL_curstackinfo = next;                
    SET_MARK_OFFSET;		
}

void Perl_pop_stack(pTHX)
{
    dSP;								
    PERL_SI * const prev = PL_curstackinfo->si_prev;            
    if (!prev) {						
        PerlIO_printf(Perl_error_log, "panic: POPSTACK\n");	
        my_exit(1);						
    }						
    SWITCHSTACK(PL_curstack,prev->si_stack);
#ifdef DEBUGGING
    PL_debug = PL_curstackinfo->olddebug;	
#endif /* DEBUGGING */
    /* don't free prev here, free them all at the END{} */	
    PL_curstackinfo = prev;					
}
