
void
Perl_save_hints(pTHX) {
    HvREFCNT_inc(PL_compiling.cop_hints_hash);
    if (PL_hints & HINT_LOCALIZE_HH) {
        save_pushptri32ptr(PL_hinthv, PL_hints, PL_compiling.cop_hints_hash, SAVEt_HINTS);
        PL_hinthv = newHVhv(PL_hinthv);
    }
    else {
        save_pushi32ptr(PL_hints, PL_compiling.cop_hints_hash, SAVEt_HINTS);
    }
}

void
Perl_save_pushptri32ptr(pTHX_ void *const ptr1, const I32 i, void *const ptr2,
			const int type)
{
    SSCHECK(4);
    SSPUSHPTR(ptr1);
    SSPUSHINT(i);
    SSPUSHPTR(ptr2);
    SSPUSHINT(type);
}

void
Perl_save_pushi32ptr(pTHX_ const I32 i, void *const ptr, const int type)
{
    dVAR;
    SSCHECK(3);
    SSPUSHINT(i);
    SSPUSHPTR(ptr);
    SSPUSHINT(type);
}

