
void
Perl_save_hints() {
    SSCHECK(4);
    if (PL_hints & HINT_LOCALIZE_HH) {
        SSPUSHPTR(PL_hinthv);
        PL_hinthv = newHVhv(PL_hinthv);
    }
    HvREFCNT_inc(PL_compiling.cop_hints_hash);
    SSPUSHPTR(PL_compiling.cop_hints_hash);
    SSPUSHINT(PL_hints);
    SSPUSHINT(SAVEt_HINTS);
}
