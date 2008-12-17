
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_utf8_valid);
XS(XS_utf8_encode);
XS(XS_utf8_decode);
XS(XS_utf8_unicode_to_native);
XS(XS_utf8_native_to_unicode);

void
Perl_boot_core_utf8(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    newXS("utf8::valid", XS_utf8_valid, file);
    newXS("utf8::encode", XS_utf8_encode, file);
    newXS("utf8::decode", XS_utf8_decode, file);
    newXS("utf8::native_to_unicode", XS_utf8_native_to_unicode, file);
    newXS("utf8::unicode_to_native", XS_utf8_unicode_to_native, file);
}

XS(XS_utf8_valid)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items != 1)
	  Perl_croak(aTHX_ "Usage: utf8::valid(sv)");
    else {
	SV * const sv = ST(0);
	STRLEN len;
	const char * const s = SvPV_const(sv,len);
	if (is_utf8_string(s,len))
	    XSRETURN_YES;
	else
	    XSRETURN_NO;
    }
     XSRETURN_EMPTY;
}

XS(XS_utf8_encode)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: utf8::encode(sv)");
    XSRETURN_EMPTY;
}

XS(XS_utf8_decode)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: utf8::decode(sv)");
    else {
	ST(0) = boolSV(1);
	sv_2mortal(ST(0));
    }
    XSRETURN(1);
}

XS(XS_utf8_native_to_unicode)
{
 dVAR;
 dXSARGS;
 const UV uv = SvUV(ST(0));
 PERL_UNUSED_ARG(cv);

 if (items > 1)
     Perl_croak(aTHX_ "Usage: utf8::native_to_unicode(sv)");

 ST(0) = sv_2mortal(newSViv(NATIVE_TO_UNI(uv)));
 XSRETURN(1);
}

XS(XS_utf8_unicode_to_native)
{
 dVAR;
 dXSARGS;
 const UV uv = SvUV(ST(0));
 PERL_UNUSED_ARG(cv);

 if (items > 1)
     Perl_croak(aTHX_ "Usage: utf8::unicode_to_native(sv)");

 ST(0) = sv_2mortal(newSViv(UNI_TO_NATIVE(uv)));
 XSRETURN(1);
}

