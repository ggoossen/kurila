
IO* Perl_gv_io(GV *gv) {
    PERL_ARGS_ASSERT_GV_IO;
    return GvIO(gv);
}
