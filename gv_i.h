
IO* Perl_gv_io(GV *gv) {
    PERL_ARGS_ASSERT_GV_IO;
    return GvIO(gv);
}

AV*
Perl_GvAVn(GV *gv) {
    if (GvGP(gv)->gp_av) {
	/* assert(SvTYPE(GvGP(gv)->gp_av) == SVt_PVAV); */
	return GvGP(gv)->gp_av;
    } else {
	return GvGP(gv_AVadd(gv))->gp_av;
    }
}
