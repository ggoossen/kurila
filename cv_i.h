bool
Perl_cv_assignarg_flag(pTHX_ CV* cv) { 
    return (CvFLAGS(cv) & CVf_ASSIGNARG) ? 1 : 0;
}

