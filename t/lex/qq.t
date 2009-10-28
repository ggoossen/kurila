#!./perl

print: $^STDOUT, q(1..42
)

# This is() function is written to avoid ""
my $test = 1
sub is($left, $right, ?$msg)

    if ($left eq $right)
        printf: $^STDOUT, 'ok %d
', $test++
        return 1
    
    foreach ((@: $left, $right)) {
    # Comment out these regexps to map non-printables to ord if the perl under
    # test is so broken that it's not helping
    #       s/([^-+A-Za-z_0-9])/sprintf q{'.chr(%d).'}, ord $1/ge;
    #       $_ = sprintf q('%s'), $_;
    #       s/^''\.//;
    #       s/\.''$//;
    }
    printf: $^STDOUT, q(not ok %d - got %s expected %s
), $test++, $left, $right

    printf: $^STDOUT, q(# Failed test at line %d
), (caller)[[2]]

    return 0


is: "\x{4E}", chr 78
is: "\x{6_9}", chr 105
is: "\x{_6_3}", chr 99
is: "\x{_6B}", chr 107

is: "\x{9__0}", chr 9		# multiple underscores not allowed.
is: "\x{77_}", chr 119	# trailing underscore warns.
is: "\x{6FQ}z", (chr: 111) . 'z'

is: "\x{0x4E}", chr 0
is: "\x{x4E}", chr 0

is: "\x[65]", chr 101
is: "\x[FF]", (bytes::chr: 0xFF)
is: "\x[\%0]", chr 0
is: "\x[9]", ''
is: "\x[FF9]", "\x[FF]"

is: " \{ 1 \} ", ' { 1 } ', " curly braces"
is: qq{ \{ 1 \} }, ' { 1 } ', " curly braces inside curly braces"

is: eval "qq\x{263A}foo\x{263A}", 'foo', "Unicode delimeters"

do
    local $^WARN_HOOK = sub { }
    is: eval '"\x53"', chr 83
    is: eval '"\x4EE"', (chr: 78) . 'E'
    is: eval '"\x4i"', (chr: 4) . 'i'	# This will warn
    is: eval '"\xh"', (chr: 0) . 'h'	# This will warn
    is: eval '"\xx"', (chr: 0) . 'x'	# This will warn
    is: eval '"\xx9"', (chr: 0) . 'x9'	# This will warn. \x9 is tab in EBCDIC too?
    is: eval '"\x9_E"', (chr: 9) . '_E'	# This will warn


do
    require utf8
    is: "\x{0065}", (utf8::chr: 101)
    is: "\x{000000000000000000000000000000000000000000000000000000000000000072}"
        (utf8::chr: 114)
    is: "\x{0_06_5}", (utf8::chr: 101)
    is: "\x{1234}", (utf8::chr: 4660)
    is: "\x{10FFFD}", (utf8::chr: 1114109)

    use charnames ':full';
    is: "\N{LATIN SMALL LETTER A}", "a"
    is: "\N{NEL}", (utf8::chr: 0x85)


# variable interpolation
do
    our (@: $a, $b, ?$c, ?$dx) =  qw(foo bar)
    my $da = \$a

    is: "$a", "foo",    "verifying assign"
    is: "$a$b", "foobar", "basic concatenation"
    is: "$c$a$c", "foo",    "concatenate undef, fore and aft"
    is: "$da->$x", "foox", "interpolation till ->\$"

    # Array and derefence, this doesn't really belong in 'op/concat' but I
    # couldn't find a better place

    my @x = qw|aap noot|
    my $dx = \ @x

    is: "$((join: ' ',@x))", "aap noot"
    is: "$((join: ' ',$dx->@))", "aap noot"

    # Okay, so that wasn't very challenging.  Let's go Unicode.

    do
        use utf8
        # bug id 20000819.004

        $_ = $dx = "\x{10f2}"
        s/($dx)/$dx$1/
        do
            is: $_,  "$dx$dx","bug id 20000819.004, back"
        

        $_ = $dx = "\x{10f2}"
        s/($dx)/$1$dx/
        do
            is: $_,  "$dx$dx","bug id 20000819.004, front"
        

        $dx = "\x{10f2}"
        $_  = "\x{10f2}\x{10f2}"
        s/($dx)($dx)/$1$2/
        do
            is: $_,  "$dx$dx","bug id 20000819.004, front and back"
        
    

    do
        # bug id 20000901.092
        # test that undef left and right of utf8 results in a valid string

        use utf8

        my $a
        $a .= "\x{1ff}"
        is: $a,  "\x{1ff}", "bug id 20000901.092, undef left"
        $a .= undef
        is: $a,  "\x{1ff}", "bug id 20000901.092, undef right"
    


  
