bool Perl_UTF8_IS_CONTINUATION(const char c) {
    return (((U8)c) >= 0x80) && (((U8)c) <= 0xbf);
}

bool Perl_UTF8_IS_CONTINUED(const char c) {
    return (U8)c & 0x80;
}
