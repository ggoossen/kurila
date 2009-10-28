#!./perl -w

#P = start of string  Q = start of substr  R = end of substr  S = end of string

use warnings 


our ($w, $FATAL_MSG, $x)

$a = 'abcdefxyz'
$^WARN_HOOK = sub (@< @_)
    if (@_[0]->{?description} =~ m/^substr outside of string/)
        $w++
    elsif (@_[0]->{?description} =~ m/^Attempt to use reference as lvalue in substr/)
        $w += 2
    elsif (@_[0]->{?description} =~ m/^Use of uninitialized value/)
        $w += 3
    else
        warn: @_[0]->{?description}
    


require './test.pl'

plan: 232

run_tests:  unless caller

my $krunch = "a"

sub run_tests

    $FATAL_MSG = qr/^substr outside of string/

    is: (substr: $a,0,3), 'abc'   # P=Q R S
    is: (substr: $a,3,3), 'def'   # P Q R S
    is: (substr: $a,6,999), 'xyz' # P Q S R
    $b = substr: $a,999,999  # warn # P R Q S
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,999,999, "") ; }# P R Q S
                $FATAL_MSG
    is: (substr: $a,0,-6), 'abc'  # P=Q R S
    is: (substr: $a,-3,1), 'x'    # P Q R S

    substr: $a,3,3, 'XYZ'
    is: $a, 'abcXYZxyz' 
    substr: $a,0,2, ''
    is: $a, 'cXYZxyz' 
    substr: $a,0,0, 'ab'
    is: $a, 'abcXYZxyz' 
    substr: $a,0,0, '12345678'
    is: $a, '12345678abcXYZxyz' 
    substr: $a,-3,3, 'def'
    is: $a, '12345678abcXYZdef'
    substr: $a,-3,3, '<'
    is: $a, '12345678abcXYZ<' 
    substr: $a,-1,1, '12345678'
    is: $a, '12345678abcXYZ12345678' 

    $a = 'abcdefxyz'

    is: (substr: $a,6), 'xyz'         # P Q R=S
    is: (substr: $a,-3), 'xyz'        # P Q R=S
    $b = substr: $a,999,999  # warning   # P R=S Q
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a,999,999, "") ; }     # P R=S Q
               $FATAL_MSG
    is: (substr: $a,0), 'abcdefxyz'  # P=Q R=S
    is: (substr: $a,9), ''           # P Q=R=S
    is: (substr: $a,-11), 'abcdefxyz' # Q P R=S
    is: (substr: $a,-9), 'abcdefxyz'  # P=Q R=S

    $a = '54321'

    $b = substr: $a,-7, 1  # warn  # Q R P S
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a,-7, 1, "") ; } # Q R P S
               $FATAL_MSG
    $b = substr: $a,-7,-6  # warn  # Q R P S
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a,-7,-6, "") ; } # Q R P S
               $FATAL_MSG
    is: (substr: $a,-5,-7), ''  # R P=Q S
    is: (substr: $a, 2,-7), ''  # R P Q S
    is: (substr: $a,-3,-7), ''  # R P Q S
    is: (substr: $a, 2,-5), ''  # P=R Q S
    is: (substr: $a,-3,-5), ''  # P=R Q S
    is: (substr: $a, 2,-4), ''  # P R Q S
    is: (substr: $a,-3,-4), ''  # P R Q S
    is: (substr: $a, 5,-6), ''  # R P Q=S
    is: (substr: $a, 5,-5), ''  # P=R Q S
    is: (substr: $a, 5,-3), ''  # P R Q=S
    $b = substr: $a, 7,-7  # warn  # R P S Q
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a, 7,-7, "") ; } # R P S Q
               $FATAL_MSG
    $b = substr: $a, 7,-5  # warn  # P=R S Q
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a, 7,-5, "") ; } # P=R S Q
               $FATAL_MSG
    $b = substr: $a, 7,-3  # warn  # P Q S Q
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a, 7,-3, "") ; } # P Q S Q
               $FATAL_MSG
    $b = substr: $a, 7, 0  # warn  # P S Q=R
    is: $w--, 1
    dies_like: sub (@< @_) {(substr: $a, 7, 0, "") ; } # P S Q=R
               $FATAL_MSG

    is: (substr: $a,-7,2), ''   # Q P=R S
    is: (substr: $a,-7,4), '54' # Q P R S
    is: (substr: $a,-7,7), '54321'# Q P R=S
    is: (substr: $a,-7,9), '54321'# Q P S R
    is: (substr: $a,-5,0), ''   # P=Q=R S
    is: (substr: $a,-5,3), '543'# P=Q R S
    is: (substr: $a,-5,5), '54321'# P=Q R=S
    is: (substr: $a,-5,7), '54321'# P=Q S R
    is: (substr: $a,-3,0), ''   # P Q=R S
    is: (substr: $a,-3,3), '321'# P Q R=S
    is: (substr: $a,-2,3), '21' # P Q S R
    is: (substr: $a,0,-5), ''   # P=Q=R S
    is: (substr: $a,2,-3), ''   # P Q=R S
    is: (substr: $a,0,0), ''    # P=Q=R S
    is: (substr: $a,0,5), '54321'# P=Q R=S
    is: (substr: $a,0,7), '54321'# P=Q S R
    is: (substr: $a,2,0), ''    # P Q=R S
    is: (substr: $a,2,3), '321' # P Q R=S
    is: (substr: $a,5,0), ''    # P Q=R=S
    is: (substr: $a,5,2), ''    # P Q=S R
    is: (substr: $a,-7,-5), ''  # Q P=R S
    is: (substr: $a,-7,-2), '543'# Q P R S
    is: (substr: $a,-5,-5), ''  # P=Q=R S
    is: (substr: $a,-5,-2), '543'# P=Q R S
    is: (substr: $a,-3,-3), ''  # P Q=R S
    is: (substr: $a,-3,-1), '32'# P Q R S

    $a = ''

    is: (substr: $a,-2,2), ''   # Q P=R=S
    is: (substr: $a,0,0), ''    # P=Q=R=S
    is: (substr: $a,0,1), ''    # P=Q=S R
    is: (substr: $a,-2,3), ''   # Q P=S R
    is: (substr: $a,-2), ''     # Q P=R=S
    is: (substr: $a,0), ''      # P=Q=R=S


    is: (substr: $a,0,-1), ''   # R P=Q=S
    $b = substr: $a,-2, 0  # warn  # Q=R P=S
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,-2, 0, "") ; } # Q=R P=S
                $FATAL_MSG

    $b = substr: $a,-2, 1  # warn  # Q R P=S
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,-2, 1, "") ; } # Q R P=S
                $FATAL_MSG

    $b = substr: $a,-2,-1  # warn  # Q R P=S
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,-2,-1, "") ; } # Q R P=S
                $FATAL_MSG

    $b = substr: $a,-2,-2  # warn  # Q=R P=S
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,-2,-2, "") ; } # Q=R P=S
                $FATAL_MSG

    $b = substr: $a, 1,-2  # warn  # R P=S Q
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a, 1,-2, "") ; } # R P=S Q
                $FATAL_MSG

    $b = substr: $a, 1, 1  # warn  # P=S Q R
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a, 1, 1, "") ; } # P=S Q R
                $FATAL_MSG

    $b = substr: $a, 1, 0 # warn   # P=S Q=R
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a, 1, 0, "") ; } # P=S Q=R
                $FATAL_MSG

    $b = substr: $a,1  # warning   # P=R=S Q
    is: $w--, 1
    dies_like:  sub (@< @_) {(substr: $a,1, undef, "") ; }     # P=R=S Q
                $FATAL_MSG

    my $a = 'zxcvbnm'
    substr: $a,2,0, ''
    is: $a, 'zxcvbnm'
    substr: $a,7,0, ''
    is: $a, 'zxcvbnm'
    substr: $a,5,0, ''
    is: $a, 'zxcvbnm'
    substr: $a,0,2, 'pq'
    is: $a, 'pqcvbnm'
    substr: $a,2,0, 'r'
    is: $a, 'pqrcvbnm'
    substr: $a,8,0, 'asd'
    is: $a, 'pqrcvbnmasd'
    substr: $a,0,2, 'iop'
    is: $a, 'ioprcvbnmasd'
    substr: $a,0,5, 'fgh'
    is: $a, 'fghvbnmasd'
    substr: $a,3,5, 'jkl'
    is: $a, 'fghjklsd'
    substr: $a,3,2, '1234'
    is: $a, 'fgh1234lsd'


    my $txt = "Foo"
    substr: $txt, -1, undef, "X"
    is: $txt, "FoX"

    # with lexicals (and in re-entered scopes)
    for ((@: 0,1))
        my $txt
        unless ($_)
            $txt = "Foo"
            substr: $txt, -1, undef, "X"
            is: $txt, "FoX"
        else
            substr: $txt, 0, 1, "X"
            is: $txt, "X"
        
    

    $w = 0 
    # coercion of references
    do
        my $s = \$@
        dies_like:  sub (@< @_) { (substr: $s, 0, 1, 'Foo'); }, qr/reference as string/ 
    

    # check no spurious warnings
    is: $w, 0

    # check new 4 arg replacement syntax
    $a = "abcxyz"
    $w = 0
    is: (substr: $a, 0, 3, ""), "abc"
    is: $a, "xyz"
    is: (substr: $a, 0, 0, "abc"), ""
    is: $a, "abcxyz"
    is: (substr: $a, 3, -1, ""), "xy"
    is: $a, "abcz"

    is: (substr: $a, 3, undef, "xy"), "z"
    is: $a, "abcxy"
    is: $w, 0

    $w = 0

    is: (substr: $a, 3, 9999999, ""), "xy"
    is: $a, "abc"
    dies_like: sub (@< @_) {(substr: $a, -99, 0, "") }
               $FATAL_MSG
    dies_like: sub (@< @_) {(substr: $a, 99, 3, "") }
               $FATAL_MSG

    substr: $a, 0, (length: $a), "foo"
    is: $a, "foo"
    is: $w, 0

    # using 4 arg substr as lvalue is a compile time error
    eval_dies_like:  'substr($a,0,0,"") = "abc"'
                     qr/Can't assign to substr/
    is: $a, "foo"

    $a = "abcdefgh"
    is: (sub (@< @_) { shift }->& <: (substr: $a, 0, 4, "xxxx")), 'abcd'
    is: $a, 'xxxxefgh'

    do
        my $y = 10
        $y = "2" . $y
        is: $y, 210
    

    # utf8 sanity
    do
        use utf8
        my $x = substr: "a\x{263a}b",0
        $x = substr: $x,1,1
        is: $x, "\x{263a}"

        $x = "\x{263a}\x{263a}"
        substr: $x,0,1, "abcd"
        is: $x, "abcd\x{263a}"
        $x = join: '', reverse: split: m//, $x
        is: $x, "\x{263a}dcba"
    
    do
        # using bytes.
        no utf8
        my $x = substr: "a" . (utf8::chr: 0x263a) . "b",0 # \x{263a} == \xE2\x98\xBA
        $x = substr: $x,1,1
        is: $x, "\x[E2]"
        $x = $x x 2
        substr: $x,0,1, "abcd"
        is: $x, "abcd\x[E2]"
        $x = join: '', reverse: split: m//, $x
        is: $x, "\x[E2]dcba"
    

    # And tests for already-UTF8 one

    use utf8
    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, 1, "\x{100}"
    is: (length: $x), 3
    is: $x, "\x{100}\x{F2}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, 1, "\x{100}\x{FF}"
    is: (length: $x), 4
    is: $x, "\x{100}\x{FF}\x{F2}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{FF}"
    is: (substr: $x, 2, 1), "\x{F2}"
    is: (substr: $x, 3, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, 2, "\x{100}\x{FF}"
    is: (length: $x), 3
    is: $x, "\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{FF}"
    is: (substr: $x, 2, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 1, 1, "\x{100}\x{FF}"
    is: (length: $x), 4
    is: $x, "\x{101}\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{100}"
    is: (substr: $x, 2, 1), "\x{FF}"
    is: (substr: $x, 3, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 2, 1, "\x{100}\x{FF}"
    is: (length: $x), 4
    is: $x, "\x{101}\x{F2}\x{100}\x{FF}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{100}"
    is: (substr: $x, 3, 1), "\x{FF}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 3, 1, "\x{100}\x{FF}"
    is: (length: $x), 5
    is: $x, "\x{101}\x{F2}\x{F3}\x{100}\x{FF}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{F3}"
    is: (substr: $x, 3, 1), "\x{100}"
    is: (substr: $x, 4, 1), "\x{FF}"

    $x = "\x{101}\x{F2}\x{100}\x{FF}"
    is: $x, "\x{101}\x{F2}\x{100}\x{FF}"
    substr: $x, -2, 1, "\x{104}\x{105}"
    is: (length: $x), 5
    is: $x, "\x{101}\x{F2}\x{104}\x{105}\x{FF}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{104}"
    is: (substr: $x, 3, 1), "\x{105}"
    is: (substr: $x, 4, 1), "\x{FF}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, -1, 0, "\x{100}\x{FF}"
    is: (length: $x), 5
    is: $x, "\x{101}\x{F2}\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{100}"
    is: (substr: $x, 3, 1), "\x{FF}"
    is: (substr: $x, 4, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, -1, "\x{100}\x{FF}"
    is: (length: $x), 3
    is: $x, "\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{FF}"
    is: (substr: $x, 2, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, -2, "\x{100}\x{FF}"
    is: (length: $x), 4
    is: $x, "\x{100}\x{FF}\x{F2}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{FF}"
    is: (substr: $x, 2, 1), "\x{F2}"
    is: (substr: $x, 3, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 0, -3, "\x{100}\x{FF}"
    is: (length: $x), 5
    is: $x, "\x{100}\x{FF}\x{101}\x{F2}\x{F3}"
    is: (substr: $x, 0, 1), "\x{100}"
    is: (substr: $x, 1, 1), "\x{FF}"
    is: (substr: $x, 2, 1), "\x{101}"
    is: (substr: $x, 3, 1), "\x{F2}"
    is: (substr: $x, 4, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, 1, -1, "\x{100}\x{FF}"
    is: (length: $x), 4
    is: $x, "\x{101}\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{100}"
    is: (substr: $x, 2, 1), "\x{FF}"
    is: (substr: $x, 3, 1), "\x{F3}"

    $x = "\x{101}\x{F2}\x{F3}"
    substr: $x, -1, -1, "\x{100}\x{FF}"
    is: (length: $x), 5
    is: $x, "\x{101}\x{F2}\x{100}\x{FF}\x{F3}"
    is: (substr: $x, 0, 1), "\x{101}"
    is: (substr: $x, 1, 1), "\x{F2}"
    is: (substr: $x, 2, 1), "\x{100}"
    is: (substr: $x, 3, 1), "\x{FF}"
    is: (substr: $x, 4, 1), "\x{F3}"

    substr: ($x = "ab"), 0, 0, "\x{100}\x{200}"
    is: $x, "\x{100}\x{200}ab"

    substr: ($x = "\x{100}\x{200}"), 0, 0, "ab"
    is: $x, "ab\x{100}\x{200}"

    substr: ($x = "ab"), 1, 0, "\x{100}\x{200}"
    is: $x, "a\x{100}\x{200}b"

    substr: ($x = "\x{100}\x{200}"), 1, 0, "ab"
    is: $x, "\x{100}ab\x{200}"

    substr: ($x = "ab"), 2, 0, "\x{100}\x{200}"
    is: $x, "ab\x{100}\x{200}"

    substr: ($x = "\x{100}\x{200}"), 2, 0, "ab"
    is: $x, "\x{100}\x{200}ab"

    # [perl #20933]
    do
        my $s = "ab"
        my @r
        for (@: 0, 1)
            @r[+$_] = \ substr: $s, $_, 1
        is: (join: "", (map: { $_->$ }, @r)), "ab"

    # [perl #24605]
    do
        my $x = "0123456789\x{500}"
        my $y = substr: $x, 4
        is: (substr: $x, 7, 1), "7"
    

    # multiple assignments to lvalue [perl #24346]
    do
        is: ref \(substr: $x,1,3), "SCALAR", "not an lvalue"
        my $x = "abcdef"
        for ((@: (substr: $x,1,3)))
            is: $_, 'bcd'
            $_ = 'XX'
            is: $_, 'XX'
            is: $x, 'abcdef'
        
    

    # [perl #29149]
    do
        my $text  = "0123456789\x{ED} "
        my $pos = 5
        pos: $text, $pos
        my $a = substr: $text, $pos, $pos
        is: (substr: $text,$pos,1), $pos

    

    # [perl #34976] incorrect caching of utf8 substr length
    do
        my  $a = "abcd\x{100}"
        is: (substr: $a,1,2), 'bc'
        is: (substr: $a,1,1), 'b'
    

    do
        # lvalue ref count
        my $foo = "bar"
        is: (Internals::SvREFCNT: \$foo), 2
        substr: $foo, -2, 2, "la"
        is: (Internals::SvREFCNT: \$foo), 2
    


