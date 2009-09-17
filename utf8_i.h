bool Perl_UTF8_IS_CONTINUATION(const char c) {
    return (((U8)c) >= 0x80) && (((U8)c) <= 0xbf);
}

bool Perl_UTF8_IS_CONTINUED(const char c) {
    return (U8)c & 0x80;
}

/* IS_UTF8_CHAR(p) is strictly speaking wrong (not UTF-8) because it
 * (1) allows UTF-8 encoded UTF-16 surrogates
 * (2) it allows code points past U+10FFFF.
 * The Perl_is_utf8_char() full "slow" code will handle the Perl
 * "extended UTF-8". */

/*

Tests if some arbitrary number of bytes begins in a valid UTF-8
character.  Note that an INVARIANT (i.e. ASCII) character is a valid
UTF-8 character.  The actual number of bytes in the UTF-8 character
will be returned if it is valid, otherwise 0.

This is the "slow" version as opposed to the "fast" version which is
the "unrolled" IS_UTF8_CHAR().  E.g. for t/uni/class.t the speed
difference is a factor of 2 to 3.  For lengths (UTF8SKIP(s)) of four
or less you should use the IS_UTF8_CHAR(), for lengths of five or more
you should use the _slow().  In practice this means that the _slow()
will be used very rarely, since the maximum Unicode code point (as of
Unicode 4.1) is U+10FFFF, which encodes in UTF-8 to four bytes.  Only
the "Perl extended UTF-8" (the infamous 'v-strings') will encode into
five bytes or more.

=cut */
STRLEN
Perl_is_utf8_char_slow(const char *s, const STRLEN len)
{
    char u = *s;
    STRLEN slen;
    UV uv, ouv;

    PERL_ARGS_ASSERT_IS_UTF8_CHAR_SLOW;

    if (UTF8_IS_INVARIANT(u))
	return 1;

    if (!UTF8_IS_START(u))
	return 0;

    if (len < 2 || !Perl_UTF8_IS_CONTINUATION(aTHX_ s[1]))
	return 0;

    slen = len - 1;
    s++;
    u &= UTF_START_MASK(len);
    uv  = u;
    ouv = uv;
    while (slen--) {
	if (!Perl_UTF8_IS_CONTINUATION(aTHX_ *s))
	    return 0;
	uv = UTF8_ACCUMULATE(uv, *s);
	if (uv < ouv) 
	    return 0;
	ouv = uv;
	s++;
    }

    if ((STRLEN)UNISKIP(uv) < len)
	return 0;

    return len;
}


/*
=for apidoc is_utf8_char

Tests if some arbitrary number of bytes begins in a valid UTF-8
character.  Note that an INVARIANT (i.e. ASCII on non-EBCDIC machines)
character is a valid UTF-8 character.  The actual number of bytes in the UTF-8
character will be returned if it is valid, otherwise 0.

=cut */
STRLEN
Perl_is_utf8_char(const char *s)
{
    const STRLEN len = UTF8SKIP(s);

    PERL_ARGS_ASSERT_IS_UTF8_CHAR;
    if (IS_UTF8_CHAR_FAST(len)) {
        return (
            len == 1 ? ( IS_UTF8_CHAR_1((U8*)s) ? len : 0 ) :
            len == 2 ? ( IS_UTF8_CHAR_2((U8*)s) ? len : 0 ) :
            len == 3 ? ( IS_UTF8_CHAR_3((U8*)s) ? len : 0 ) :
            len == 4 ? ( IS_UTF8_CHAR_4((U8*)s) ? len : 0 ): 0
            );
    }
    return Perl_is_utf8_char_slow(aTHX_ s, len);
}

