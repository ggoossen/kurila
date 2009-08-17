OP*
Perl_RootopOp(pTHX_ ROOTOP* o) {
    return (OP*)o;
}

LISTOP*
Perl_opTlistop(pTHX_ OP* o) {
    return (LISTOP*)o;
}

void
Perl_rootop_refcnt_dec(pTHX_ ROOTOP* o) {
    PADOFFSET refcnt = OpREFCNT_dec(o);
    PERL_ARGS_ASSERT_ROOTOP_REFCNT_DEC;
    if (refcnt == 0) {
	ENTER_named("op_free");
	PAD_SAVE_SETNULLPAD();

        op_free(RootopOp(o));
        
        LEAVE_named("op_free");
    }
}

void
Perl_rootop_refcnt_inc(pTHX_ ROOTOP* o) {
    PERL_ARGS_ASSERT_ROOTOP_REFCNT_INC;
    OpREFCNT_inc(o);
}
