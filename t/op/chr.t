#!./perl

BEGIN 
    require "./test.pl"


plan: tests => 39

# Note that t/op/ord.t already tests for chr() <-> ord() rountripping.

# Don't assume ASCII.

is: (chr: (ord: "A")), "A"

do
    # byte characters
    use bytes
    is: (chr:   0), "\x[00]"
    is: (chr: 127), "\x[7F]"
    is: (chr: 128), "\x[80]"
    is: (chr: 255), "\x[FF]"


do
    # unicode characters
    use utf8
    is: (chr: -0.1), "\x{FFFD}" # The U+FFFD Unicode replacement character.
    is: (chr: -1  ), "\x{FFFD}"
    is: (chr: -2  ), "\x{FFFD}"
    is: (chr: -3.0), "\x{FFFD}"


do
    # ASCII characters
    is: (chr: 0x65), "\x[65]"
    my $warn
    $^WARN_HOOK = sub (@< @_) { $warn = shift->message }
    is: (chr: 0x80), "\x[80]"
    like: $warn, qr"chr\(\) ambiguous with highbit without use bytes or use utf8", "highbit warning"


do
    use bytes
    is: (chr: -0.1), "\x[00]"
    is: (chr: -1  ), "\x[FF]"
    is: (chr: -2  ), "\x[FE]"
    is: (chr: -3.0), "\x[FD]"


do
    use utf8
    is: (utf8::chr: 0xFF), "\x{FF}"
    is: (bytes::chr: 0xFF), "\x[FF]"


# Check UTF-8

sub hexes
    no warnings 'utf8' # avoid surrogate and beyond Unicode warnings
    use utf8
    join: " ", (map: {(sprintf: "\%02x",$_)}, (@: (unpack: "C*",(chr: @_[0]))))


# The following code points are some interesting steps in UTF-8.
is: (hexes:    0x100), "c4 80"
is: (hexes:    0x7FF), "df bf"
is: (hexes:    0x800), "e0 a0 80"
is: (hexes:    0xFFF), "e0 bf bf"
is: (hexes:   0x1000), "e1 80 80"
is: (hexes:   0xCFFF), "ec bf bf"
is: (hexes:   0xD000), "ed 80 80"
is: (hexes:   0xD7FF), "ed 9f bf"
is: (hexes:   0xD800), "ed a0 80" # not strict utf-8 (surrogate area begin)
is: (hexes:   0xDFFF), "ed bf bf" # not strict utf-8 (surrogate area end)
is: (hexes:   0xE000), "ee 80 80"
is: (hexes:   0xFFFF), "ef bf bf"
is: (hexes:  0x10000), "f0 90 80 80"
is: (hexes:  0x3FFFF), "f0 bf bf bf"
is: (hexes:  0x40000), "f1 80 80 80"
is: (hexes:  0xFFFFF), "f3 bf bf bf"
is: (hexes: 0x100000), "f4 80 80 80"
is: (hexes: 0x10FFFF), "f4 8f bf bf" # Unicode (4.1) last code point
is: (hexes: 0x110000), "f4 90 80 80"
is: (hexes: 0x1FFFFF), "f7 bf bf bf" # last four byte encoding
is: (hexes: 0x200000), "f8 88 80 80 80"
