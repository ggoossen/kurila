bool
Perl_cv_assignarg_flag(pTHX_ CV* cv)
{ 
    PERL_ARGS_ASSERT_CV_ASSIGNARG_FLAG;
    return (CvFLAGS(cv) & CVf_ASSIGNARG) ? 1 : 0;
}

bool
Perl_cv_optassignarg_flag(pTHX_ CV* cv)
{ 
    PERL_ARGS_ASSERT_CV_OPTASSIGNARG_FLAG;
    return (CvFLAGS(cv) & CVf_OPTASSIGNARG) ? 1 : 0;
}
