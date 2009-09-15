
void 
Perl_pad_set_cur_nosave(pTHX_ AV* padlist, I32 nth) {
    AVcpREPLACE(PL_comppad, (PAD*) (AvARRAY(padlist)[nth]));
    PL_curpad = AvARRAY(PL_comppad);           
    DEBUG_Xv(PerlIO_printf(Perl_debug_log,    
            "Pad 0x%"UVxf"[0x%"UVxf"] set_cur    depth=%d\n",
            PTR2UV(PL_comppad), PTR2UV(PL_curpad), (int)(nth)));
}
