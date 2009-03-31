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
    if (refcnt == 0) {
	ENTER;
	PAD_SAVE_SETNULLPAD();

        op_free(RootopOp(o));
        
        LEAVE;
    }
}

void
Perl_rootop_refcnt_inc(pTHX_ ROOTOP* o) {
    OpREFCNT_inc(o);
}
