#!./perl -w

BEGIN 
    require './test.pl'


# This is truth in an if statement, and could be a skip message
my $no_endianness = ''
my $no_signedness = ''

plan: tests => 14651

use warnings < qw(FATAL all)
use Config

my $Perl = (which_perl: )
my @valid_errors = @: qr/^Invalid type '\w'/

my $ByteOrder = 'unknown'
my $maybe_not_avail = '(?:hto[bl]e|[bl]etoh)'
if ($no_endianness)
    push: @valid_errors, qr/^Invalid type '[<>]'/
elsif ((config_value: "byteorder") =~ m/^1234(?:5678)?$/)
    $ByteOrder = 'little'
    $maybe_not_avail = '(?:htobe|betoh)'
elsif ((config_value: "byteorder") =~ m/^(?:8765)?4321$/)
    $ByteOrder = 'big'
    $maybe_not_avail = '(?:htole|letoh)'
else
    push: @valid_errors, qr/^Can't (?:un)?pack (?:big|little)-endian .*? on this platform/


if ($no_signedness)
    push: @valid_errors, qr/^'!' allowed only after types sSiIlLxX in (?:un)?pack/


for my $size ((@:  16, 32, 64) )
    if (defined config_value: "u$($size)size"
          and ((config_value: "u$($size)size")||0) != ($size >> 3))
        push: @valid_errors, qr/^Perl_my_$maybe_not_avail$size\(\) not available/
    


my $IsTwosComplement = (pack: 'i', -1) eq "\x[FF]" x config_value: "intsize"
info: "\$IsTwosComplement = $IsTwosComplement"

sub is_valid_error
    my $err = shift
    $err = $err && $err->message: 
    for my $e ( @valid_errors)
        $err =~ $e and return 1
    

    return 0


sub encode_list
    my @result = @+: map: { (_qq: $_) }, @_
    if ((nelems @result) == 1)
        return @result
    
    return '(' . (join: ', ', @result) . ')'



sub list_eq($l, $r)
    return 0 unless (nelems $l->@) == nelems $r->@
    for my $i (0..(nelems $l->@) -1)
        if (defined $l->[$i])
            return 0 unless (defined: $r->[$i]) && $l->[$i] eq $r->[$i]
        else
            return 0 if defined $r->[$i]
        
    
    return 1


##############################################################################
#
# Here starteth the tests
#

do
    my $format = "c2 x5 C C x s d i l a6"
    # Need the expression in here to force ary[5] to be numeric.  This avoids
    # test2 failing because ary2 goes str->numeric->str and ary doesn't.
    my @ary = @: 1,-100,127,128,32767,987.654321098 / 100.0,12345,123456
                 "abcdef"
    my $foo = pack: $format,< @ary
    my @ary2 = @:  unpack: $format,$foo 

    is: (scalar nelems @ary), (scalar nelems @ary2)

    my $out1=join: ':', @ary
    my $out2=join: ':', @ary2
    # Using long double NVs may introduce greater accuracy than wanted.
    $out1 =~ s/:9\.87654321097999\d*:/:9.87654321098:/
    $out2 =~ s/:9\.87654321097999\d*:/:9.87654321098:/
    is: $out1, $out2

    like: $foo, qr/def/

# How about counting bits?

do
    my $x
    is:  ($x = (unpack: "\%32B*", "\001\002\004\010\020\040\100\200\377")), 16 

    is:  ($x = (unpack: "\%32b69", "\001\002\004\010\020\040\100\200\017")), 12 

    is:  ($x = (unpack: "\%32B69", "\001\002\004\010\020\040\100\200\017")), 9 


do
    my $sum = 129 # ASCII

    my $x
    is:  ($x = (unpack: "\%32B*", "Now is the time for all good blurfl")), $sum 

    my $foo
    (open: my $bin, '<', $Perl) || die: "Can't open $Perl: $^OS_ERROR\n"
    binmode: $bin
    sysread: $bin, $foo, 8192
    close $bin

    $sum = unpack: "\%32b*", $foo
    my $longway = unpack: "b*", $foo
    is:  $sum, (nelems: @: $longway =~ m/(1)/g) 


do
    my $x
    is:  ($x = (unpack: "I",(pack: "I", 0xFFFFFFFF))), 0xFFFFFFFF 

    is: (length: (pack: 'l', 0)), 4, "pack 'l' is 4 bytes"
    use bytes;
    use utf8;
    require bytes
    is: (bytes::length: (pack: 'l', 0)), 4, "pack 'l' independent of 'use utf8'"


do
    # check 'w'
    my @x = @: 5,130,256,560,32000,3097152,268435455,1073741844, 2**33
               '4503599627365785','23728385234614992549757750638446'
    my $x = pack: 'w*', < @x
    my $y = pack: 'H*', '0581028200843081fa0081bd8440ffffff7f8480808014A0808'.
                      '0800087ffffffffffdb19caefe8e1eeeea0c2e1e3e8ede1ee6e'

    is: $x, $y

    my @y = @:  unpack: 'w*', $y 
    my $a
    while ($a = pop @x)
        my $b = pop @y
        is: $a, $b
    

    @y = @:  unpack: 'w2', $x 

    is: (scalar: nelems @y), 2
    is: @y[1], 130

    $x = pack: 'w', ^~^0
    $y = pack: 'w', (^~^0).''
    is: $x, $y
    is: (unpack: 'w',$x), ^~^0
    is: (unpack: 'w',$y), ^~^0

    $x = pack: 'w', ^~^0 - 1
    $y = pack: 'w', (^~^0) - 2

    if (^~^0 - 1 == (^~^0) - 2)
        is: $x, $y, "NV arithmetic"
    else
        isnt: $x, $y, "IV/NV arithmetic"
    
    cmp_ok: (unpack: 'w',$x), '==', ^~^0 - 1
    cmp_ok: (unpack: 'w',$y), '==', ^~^0 - 2

    # These should spot that pack 'w' is using NV, not double, on platforms
    # where IVs are smaller than doubles, and harmlessly pass elsewhere.
    # (tests for change 16861)
    my $x0 = 2**54+3
    my $y0 = 2**54-2

    $x = pack: 'w', $x0
    $y = pack: 'w', $y0

    if ($x0 == $y0)
        is: $x, $y, "NV arithmetic"
    else
        isnt: $x, $y, "IV/NV arithmetic"
    
    cmp_ok: (unpack: 'w',$x), '==', $x0
    cmp_ok: (unpack: 'w',$y), '==', $y0



do
    info: "test exceptions"
    my $x
    dies_like:  sub (@< @_) { $x = (unpack: 'w', (pack: 'C*', 0xff, 0xff))}
                qr/^Unterminated compressed integer/

    dies_like:  sub (@< @_) { $x = (unpack: 'w', (pack: 'C*', 0xff, 0xff, 0xff, 0xff))}
                qr/^Unterminated compressed integer/

    dies_like:  sub (@< @_) { $x = (unpack: 'w', (pack: 'C*', 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff))}
                qr/^Unterminated compressed integer/

    dies_like:  sub (@< @_) { $x = (pack: 'w', -1) }
                qr/^Cannot compress negative numbers/

    dies_like:  sub (@< @_) { $x = (pack: 'w', '1'x(1 + length ^~^0) . 'e0') }
                qr/^Can only compress unsigned integers/

    # Check that the warning behaviour on the modifiers !, < and > is as we
    # expect it for this perl.
    my $can_endian = $no_endianness ?? '' !! 'sSiIlLqQjJfFdDpP'
    my $can_shriek = 'sSiIlL'
    $can_shriek .= 'nNvV' unless $no_signedness
    # h and H can't do either, so act as sanity checks in blead
    foreach my $base (split: '', 'hHsSiIlLqQjJfFdDpPnNvV')
        foreach my $mod ((@: '', '<', '>', '!', '<!', '>!', '!<', '!>'))
            :SKIP do
                # Avoid void context warnings.
                my $a = try {(pack: "$base$mod")}
                skip: "pack can't $base", 1 if $^EVAL_ERROR and $^EVAL_ERROR->{?description} =~ m/^Invalid type '\w'/
                # Which error you get when 2 would be possible seems to be emergent
                # behaviour of pack's format parser.

                my $fails_shriek = $mod =~ m/!/ && (index: $can_shriek, $base) == -1
                my $fails_endian = $mod =~ m/[<>]/ && (index: $can_endian, $base) == -1
                my $shriek_first = $mod =~ m/^!/

                if ($no_endianness and ($mod eq '<!' or $mod eq '>!'))
                    # The ! isn't seem as part of $base. Instead it's seen as a modifier
                    # on > or <
                    $fails_shriek = 1
                    undef $fails_endian
                elsif ($fails_shriek and $fails_endian)
                    if ($shriek_first)
                        undef $fails_endian
                    
                

                if ($fails_endian)
                    if ($no_endianness)
                        # < and > are seen as pattern letters, not modifiers
                        like: $^EVAL_ERROR->{?description}, qr/^Invalid type '[<>]'/, "pack can't $base$mod"
                    else
                        like: $^EVAL_ERROR->{?description}, qr/^'[<>]' allowed only after types/
                              "pack can't $base$mod"
                    
                elsif ($fails_shriek)
                    like: $^EVAL_ERROR->{?description}, qr/^'!' allowed only after types/
                          "pack can't $base$mod"
                else
                    is: $^EVAL_ERROR, '', "pack can $base$mod"
                
            
        
    

    :SKIP do
        skip: $no_endianness, 2*3 + 2*8 if $no_endianness
        for my $mod (qw( ! < > ))
            dies_like: sub (@< @_) { $x = (pack: "a$mod", 42) }
                       qr/^'$mod' allowed only after types \S+ in pack/

            dies_like: sub (@< @_) { $x = (unpack: "a$mod", 'x'x8) }
                       qr/^'$mod' allowed only after types \S+ in unpack/
        

        for my $mod (qw( <> >< !<> !>< <!> >!< <>! ><! ))
            dies_like: sub (@< @_) { $x = (pack: "sI$($mod)s", 42, 47, 11) }
                       qr/^Can't use both '<' and '>' after type 'I' in pack/

            dies_like: sub (@< @_) { $x = (unpack: "sI$($mod)s", 'x'x16) }
                       qr/^Can't use both '<' and '>' after type 'I' in unpack/
        
    

    :SKIP do
        # Is this a stupid thing to do on VMS, VOS and other unusual platforms?

        skip: "-- the IEEE infinity model is unavailable in this configuration.", 1
            if ($^OS_NAME eq 'VMS') && !defined: (config_value: "useieee")

        skip: "-- $^OS_NAME has serious fp indigestion on w-packed infinities", 1
            if (
            ($^OS_NAME eq 'mpeix')
            ||
            ($^OS_NAME eq 'ultrix')
            ||
            ($^OS_NAME =~ m/^svr4/ && -f "/etc/issue" && -f "/etc/.relid") # NCR MP-RAS
            )

        my $inf = eval '2**1000000'

        skip: "Couldn't generate infinity - got error '$^EVAL_ERROR'", 1
            unless defined $inf and $inf == $inf / 2 and $inf + 1 == $inf

        local our $TODO = undef
        $TODO = "VOS needs a fix for posix-1022 to pass this test."
            if ($^OS_NAME eq 'vos')

        dies_like:  sub (@< @_) { $x = (pack: 'w', $inf) }
                    qr/^Cannot compress integer/, "Cannot compress integer"
    

    :SKIP do

        skip: "-- the full range of an IEEE double may not be available in this configuration.", 3
            if ($^OS_NAME eq 'VMS') && !defined: (config_value: "useieee")

        skip: "-- $^OS_NAME does not like 2**1023", 3
            if (($^OS_NAME eq 'ultrix'))

        # This should be about the biggest thing possible on an IEEE double
        my $big = eval '2**1023'

        skip: "Couldn't generate 2**1023 - got error '$^EVAL_ERROR'", 3
            unless defined $big and $big != $big / 2

        try { $x = (pack: 'w', $big) }
        is: $^EVAL_ERROR, '', "Should be able to pack 'w', $big # 2**1023"

        my $y = try {(unpack: 'w', $x)}
        is: $^EVAL_ERROR, ''
            "Should be able to unpack 'w' the result of pack 'w', $big # 2**1023"

        # I'm getting about 1e-16 on FreeBSD
        my $quotient = int: 100 * ($y - $big) / $big
        ok: $quotient +< 2 && $quotient +> -2
            "Round trip pack, unpack 'w' of $big is within 1\% ($quotient\%)"
    



info: "test the 'p' template"

# literals
is: (unpack: "p",(pack: "p","foo")), "foo"
:SKIP do
    skip: $no_endianness, 2 if $no_endianness
    is: (unpack: "p<",(pack: "p<","foo")), "foo"
    is: (unpack: "p>",(pack: "p>","foo")), "foo"

# scalars
is: (unpack: "p",(pack: "p",239)), 239
:SKIP do
    skip: $no_endianness, 2 if $no_endianness
    is: (unpack: "p<",(pack: "p<",239)), 239
    is: (unpack: "p>",(pack: "p>",239)), 239


# temps
sub foo { my $a = "a"; return $a . $a++ . $a++ }
do
    use warnings < qw(NONFATAL all);;
    my $warning
    do
        local $^WARN_HOOK = sub (@< @_)
            $warning = @_[0]->message: 
        
        my $junk = pack: "p", (foo:  < @_ )
    

    like: $warning, qr/temporary val/


# undef should give null pointer
like: (pack: "p", undef), qr/^\0+$/
:SKIP do
    skip: $no_endianness, 2 if $no_endianness
    like: (pack: "p<", undef), qr/^\0+$/
    like: (pack: "p>", undef), qr/^\0+$/


# Check for optimizer bug (e.g.  Digital Unix GEM cc with -O4 on DU V4.0B gives
#                                4294967295 instead of -1)
#				 see #ifdef __osf__ in pp.c pp_unpack
is: ((unpack: "i",(pack: "i",-1))), -1

info: "test the pack lengths of s S i I l L n N v V + modifiers"

my @lengths = @:  <
                      qw(s 2 S 2 i -4 I -4 l 4 L 4 n 2 N 4 v 2 V 4 n! 2 N! 4 v! 2 V! 4)
                  's!'  => (config_value: "shortsize"), 'S!'  => config_value: "shortsize"
                  'i!'  => (config_value: "intsize"),   'I!'  => config_value: "intsize"
                  'l!'  => (config_value: "longsize"),  'L!'  => config_value: "longsize"
    

while (my (@: ?$base, ?$expect) =(@:  (splice: @lengths, 0, 2)))
    my @formats = @: $base
    $base =~ m/^[nv]/i or push: @formats, "$base>", "$base<"
    for my $format ( @formats)
        :SKIP do
            skip: $no_endianness, 1 if $no_endianness && $format =~ m/[<>]/
            skip: $no_signedness, 1 if $no_signedness && $format =~ m/[nNvV]!/
            my $len = length: (pack: $format, 0)
            if ($expect +> 0)
                is: $expect, $len, "format '$format'"
            else
                $expect = -$expect
                (ok: $len +>= $expect, "format '$format'") ||
                    diag: "format '$format' has length $len, expected >= $expect"
            
        
    



info: "test unpack-pack lengths"

my @templates = qw(c C W i I s S l L n N v V f d q Q)

foreach my $base ( @templates)
    my @tmpl = @: $base
    $base =~ m/^[cwnv]/i or push: @tmpl, "$base>", "$base<"
    foreach my $t ( @tmpl)
        :SKIP do
            my @t = @:  try { (unpack: "$t*", (pack: "$t*", 12, 34)) } 

            skip: "cannot pack '$t' on this perl", 4
                if is_valid_error: $^EVAL_ERROR

            is:  $^EVAL_ERROR, '', "Template $t works"
            is: scalar nelems @t, 2

            is: @t[0], 12
            is: @t[1], 34
        
    


do
    # uuencode/decode

    # Note that first uuencoding known 'text' data and then checking the
    # binary values of the uuencoded version would not be portable between
    # character sets.  Uuencoding is meant for encoding binary data, not
    # text data.

    my $in = pack: 'C*', < 0 .. 255

    # just to be anal, we do some random tr/`/ /
    my $uu = <<'EOUU'
M` $"`P0%!@<("0H+# T.#Q`1$A,4%187&!D:&QP='A\@(2(C)"4F)R@I*BLL
M+2XO,#$R,S0U-C<X.3H[/#T^/T!!0D-$149'2$E*2TQ-3D]045)35%565UA9
M6EM<75Y?8&%B8V1E9F=H:6IK;&UN;W!Q<G-T=79W>'EZ>WQ]?G^`@8*#A(6&
MAXB)BHN,C8Z/D)&2DY25EI>8F9J;G)V>GZ"AHJ.DI::GJ*FJJZRMKJ^PL;*S
MM+6VM[BYNKN\O;Z_P,'"P\3%QL?(R<K+S,W.S]#1TM/4U=;7V-G:V]S=WM_@
?X>+CY.7FY^CIZNOL[>[O\/'R\_3U]O?X^?K[_/W^_P `
EOUU

    $_ = $uu
    s/ /`/g

    is: (pack: 'u', $in), $_

    is: (unpack: 'u', $uu), $in

    $in = "\x[1f]\x[8b]\x[08]\x[08]\x[58]\x[dc]\x[c4]\x[35]\x[02]\x[03]\x[4a]\x[41]\x[50]\x[55]\x[00]\x[f3]\x[2a]\x[2d]\x[2e]\x[51]\x[48]\x[cc]\x[cb]\x[2f]\x[c9]\x[48]\x[2d]\x[52]\x[08]\x[48]\x[2d]\x[ca]\x[51]\x[28]\x[2d]\x[4d]\x[ce]\x[4f]\x[49]\x[2d]\x[e2]\x[02]\x[00]\x[64]\x[66]\x[60]\x[5c]\x[1a]\x[00]\x[00]\x[00]"
    $uu = <<'EOUU'
M'XL("%C<Q#4"`TI!4%4`\RHM+E%(S,LOR4@M4@A(+<I1*"U-SD])+>("`&1F
&8%P:````
EOUU

    is: (unpack: 'u', $uu), $in

    # This is identical to the above except that backquotes have been
    # changed to spaces

    $uu = <<'EOUU'
M'XL("%C<Q#4" TI!4%4 \RHM+E%(S,LOR4@M4@A(+<I1*"U-SD])+>(" &1F
&8%P:
EOUU

    # ' # Grr
    is: (unpack: 'u', $uu), $in



# test the ascii template types (A, a, Z)

foreach (@:
    \(@: 'p', 'A*',  "foo\0bar\0 ", "foo\0bar\0 ")
    \(@: 'p', 'A11', "foo\0bar\0 ", "foo\0bar\0   ")
    \(@: 'u', 'A*',  "foo\0bar \0", "foo\0bar")
    \(@: 'u', 'A8',  "foo\0bar \0", "foo\0bar")
    \(@: 'p', 'a*',  "foo\0bar\0 ", "foo\0bar\0 ")
    \(@: 'p', 'a11', "foo\0bar\0 ", "foo\0bar\0 \0\0")
    \(@: 'u', 'a*',  "foo\0bar \0", "foo\0bar \0")
    \(@: 'u', 'a8',  "foo\0bar \0", "foo\0bar ")
    \(@: 'p', 'Z*',  "foo\0bar\0 ", "foo\0bar\0 \0")
    \(@: 'p', 'Z11', "foo\0bar\0 ", "foo\0bar\0 \0\0")
    \(@: 'p', 'Z3',  "foo",         "fo\0")
    \(@: 'u', 'Z*',  "foo\0bar \0", "foo")
    \(@: 'u', 'Z8',  "foo\0bar \0", "foo")
    )
    my (@: $what, $template, $in, $out) =  $_->@
    my $got = $what eq 'u' ?? ((unpack: $template, $in)) !! ((pack: $template, $in))
    unless ((is: $got, $out))
        my $un = $what eq 'u' ?? 'un' !! ''
        info: "$($un)pack ('$template', ".(_qq: $in).') gave '.(_qq: $out).
                   ' not '._qq: $got
    


info: "packing native shorts/ints/longs"

is: (length: (pack: "s!", 0)), (config_value: "shortsize")
is: (length: (pack: "i!", 0)), (config_value: "intsize")
is: (length: (pack: "l!", 0)), (config_value: "longsize")
ok: (length: (pack: "s!", 0)) +<= (length: (pack: "i!", 0))
ok: (length: (pack: "i!", 0)) +<= (length: (pack: "l!", 0))
is: (length: (pack: "i!", 0)), (length: (pack: "i", 0))

sub numbers
    my $base = shift
    my @formats = @: $base
    $base =~ m/^[silqjfdp]/i and push: @formats, "$base>", "$base<"
    for my $format ( @formats)
        numbers_with_total: $format, undef, < @_
    


sub numbers_with_total
    my $format = shift
    my $total = shift
    if (!defined $total)
        foreach ( @_)
            $total += $_
        
    
    info: "numbers test for $format"
    foreach ( @_)
        :SKIP do
            my $out = try {(unpack: $format, (pack: $format, $_))}
            skip: "cannot pack '$format' on this perl", 2
                if is_valid_error: $^EVAL_ERROR

            is: $^EVAL_ERROR, '', "no error $format $_"
            is: $out, $_, "unpack pack $format $_"
        
    

    my $skip_if_longer_than = ^~^0 # "Infinity"
    if (^~^0 - 1 == ^~^0)
        # If we're running with -DNO_PERLPRESERVE_IVUV and NVs don't preserve all
        # UVs (in which case ~0 is NV, ~0-1 will be the same NV) then we can't
        # correctly in perl calculate UV totals for long checksums, as pp_unpack
        # is using UV maths, and we've only got NVs.
        $skip_if_longer_than = config_value: "nv_preserves_uv_bits"
    

    foreach ((@: '', 1, 2, 3, 15, 16, 17, 31, 32, 33, 53, 54, 63, 64, 65))
        :SKIP do
            my $sum = try {(unpack: "\%$_$format*", (pack: "$format*", < @_))}
            skip: "cannot pack '$format' on this perl", 3
                if is_valid_error: $^EVAL_ERROR

            is: $^EVAL_ERROR, '', "no error"
            ok: defined $sum, "sum bits $_, format $format defined"

            my $len = $_ # Copy, so that we can reassign ''
            $len = 16 unless length $len

            :SKIP do
                skip: "cannot test checksums over $skip_if_longer_than bits", 1
                    if $len +> $skip_if_longer_than

                # Our problem with testing this portably is that the checksum code in
                # pp_unpack is able to cast signed to unsigned, and do modulo 2**n
                # arithmetic in unsigned ints, which perl has no operators to do.
                # (use integer; does signed ints, which won't wrap on UTS, which is just
                # fine with ANSI, but not with most people's assumptions.
                # This is why we need to supply the totals for 'Q' as there's no way in
                # perl to calculate them, short of unpack '%0Q' (is that documented?)
                # ** returns NVs; make sure it's IV.
                my $max = 1 + 2 * ((int: 2 ** ($len-1))-1) # The max possible checksum
                my $max_p1 = $max + 1
                my ($max_is_integer, $max_p1_is_integer)
                $max_p1_is_integer = 1 unless $max_p1 + 1 == $max_p1
                $max_is_integer = 1 if $max - 1 +< ^~^0

                my $calc_sum
                if (ref $total)
                    $calc_sum = $total->& <: $len
                else
                    $calc_sum = $total
                    # Shift into range by some multiple of the total
                    my $mult = $max_p1 ?? (int: $total / $max_p1) !! undef
                    # Need this to make sure that -1 + (~0+1) is ~0 (ie still integer)
                    $calc_sum = $total - $mult
                    $calc_sum -= $mult * $max
                    if ($calc_sum +< 0)
                        $calc_sum += 1
                        $calc_sum += $max
                    
                
                if ($calc_sum == $calc_sum - 1 && $calc_sum == $max_p1)
                    # we're into floating point (either by getting out of the range of
                    # UV arithmetic, or because we're doing a floating point checksum)
                    # and our calculation of the checksum has become rounded up to
                    # max_checksum + 1
                    $calc_sum = 0
                

                if ($calc_sum == $sum) # HAS to be ==, not eq (so no is()).
                    pass: "unpack '\%$_$format' gave $sum"
                else
                    my $delta = 1.000001
                    if ($format =~ s/[dDfF]//g
                        && ($calc_sum +<= $sum * $delta && $calc_sum +>= $sum / $delta))
                        pass: "unpack '\%$_$format' gave $sum, expected $calc_sum"
                    else
                        my $text = ref $total ??( $total->& <: $len) !! $total
                        (fail: )
                        info: "For list (" . (join: ", ", @_) . ") (total $text)"
                                   . " packed with $format unpack '\%$_$format' gave $sum,"
                                   . " expected $calc_sum"
                    
                
            
        
    


numbers: 'c', -128, -1, 0, 1, 127
numbers: 'C', 0, 1, 127, 128, 255
numbers: 'W', 0, 1, 127, 128, 255
numbers: 's', -32768, -1, 0, 1, 32767
numbers: 'S', 0, 1, 32767, 32768, 65535
numbers: 'i', -2147483648, -1, 0, 1, 2147483647
numbers: 'I', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'l', -2147483648, -1, 0, 1, 2147483647
numbers: 'L', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 's!', -32768, -1, 0, 1, 32767
numbers: 'S!', 0, 1, 32767, 32768, 65535
numbers: 'i!', -2147483648, -1, 0, 1, 2147483647
numbers: 'I!', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'l!', -2147483648, -1, 0, 1, 2147483647
numbers: 'L!', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'n', 0, 1, 32767, 32768, 65535
numbers: 'v', 0, 1, 32767, 32768, 65535
numbers: 'N', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'V', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'n!', -32768, -1, 0, 1, 32767
numbers: 'v!', -32768, -1, 0, 1, 32767
numbers: 'N!', -2147483648, -1, 0, 1, 2147483647
numbers: 'V!', -2147483648, -1, 0, 1, 2147483647
# All these should have exact binary representations:
numbers: 'f', -1, 0, 0.5, 42, 2**34
numbers: 'd', -(2**34), -1, 0, 1, 2**34
## These don't, but 'd' is NV.  XXX wrong, it's double
#numbers ('d', -1, 0, 1, 1-exp(-1), -exp(1));

numbers_with_total: 'q', -1
                    -9223372036854775808, -1, 0, 1,9223372036854775807
# This total is icky, but the true total is 2**65-1, and need a way to generate
# the epxected checksum on any system including those where NVs can preserve
# 65 bits. (long double is 128 bits on sparc, so they certainly can)
# or where rounding is down not up on binary conversion (crays)
numbers_with_total: 'Q', sub (@< @_)
                        my $len = shift
                        $len = 65 if $len +> 65 # unmasked total is 2**65-1 here
                        my $total = 1 + 2 * ((int: 2**($len - 1)) - 1)
                        return 0 if $total == $total - 1 # Overflowed integers
                        return $total # NVs still accurate to nearest integer
                    
                    0, 1,9223372036854775807, 9223372036854775808
                    18446744073709551615

info: "pack nvNV byteorders"

is: (pack: "n", 0xdead), "\x[dead]"
is: (pack: "v", 0xdead), "\x[adde]"
is: (pack: "N", 0xdeadbeef), "\x[deadbeef]"
is: (pack: "V", 0xdeadbeef), "\x[efbeadde]"

:SKIP do
    skip: $no_signedness, 4 if $no_signedness
    is: (pack: "n!", 0xdead), "\x[dead]"
    is: (pack: "v!", 0xdead), "\x[adde]"
    is: (pack: "N!", 0xdeadbeef), "\x[deadbeef]"
    is: (pack: "V!", 0xdeadbeef), "\x[efbeadde]"


info: "test big-/little-endian conversion"

sub byteorder
    my $format = shift
    info: "byteorder test for $format"
    for my $value ( @_)
        :SKIP do
            my ($nat,$be,$le)
            try { (@: $nat, $be, $le) = (map: { (pack: $format.$_, $value) }, (@:  '', '>', '<')) }
            skip: "cannot pack '$format' on this perl", 5
                if is_valid_error: $^EVAL_ERROR

            do
                use warnings < qw(NONFATAL utf8)
                info: "[$value][$nat][$be][$le][$^EVAL_ERROR]"
            

            :SKIP do
                skip: "cannot compare native byteorder with big-/little-endian", 1
                    if $ByteOrder eq 'unknown'

                is: $nat, $ByteOrder eq 'big' ?? $be !! $le
            
            is: $be, ((join: '', (reverse:  (split: m//, $le))))
            my @x = @:  try { (unpack: "$format$format>$format<", $nat.$be.$le) } 

            info: "[$value][", (join: '][', @x), "][$^EVAL_ERROR]"

            is: $^EVAL_ERROR, ''
            is: @x[0], @x[1]
            is: @x[0], @x[2]
        
    


byteorder: 's', -32768, -1, 0, 1, 32767
byteorder: 'S', 0, 1, 32767, 32768, 65535
byteorder: 'i', -2147483648, -1, 0, 1, 2147483647
byteorder: 'I', 0, 1, 2147483647, 2147483648, 4294967295
byteorder: 'l', -2147483648, -1, 0, 1, 2147483647
byteorder: 'L', 0, 1, 2147483647, 2147483648, 4294967295
byteorder: 'j', -2147483648, -1, 0, 1, 2147483647
byteorder: 'J', 0, 1, 2147483647, 2147483648, 4294967295
byteorder: 's!', -32768, -1, 0, 1, 32767
byteorder: 'S!', 0, 1, 32767, 32768, 65535
byteorder: 'i!', -2147483648, -1, 0, 1, 2147483647
byteorder: 'I!', 0, 1, 2147483647, 2147483648, 4294967295
byteorder: 'l!', -2147483648, -1, 0, 1, 2147483647
byteorder: 'L!', 0, 1, 2147483647, 2147483648, 4294967295
byteorder: 'q', -9223372036854775808, -1, 0, 1, 9223372036854775807
byteorder: 'Q', 0, 1, 9223372036854775807, 9223372036854775808, 18446744073709551615
byteorder: 'f', -1, 0, 0.5, 42, 2**34
byteorder: 'F', -1, 0, 0.5, 42, 2**34
byteorder: 'd', -(2**34), -1, 0, 1, 2**34
byteorder: 'D', -(2**34), -1, 0, 1, 2**34

info: "test negative numbers"

:SKIP do
    skip: "platform is not using two's complement for negative integers", 120
        unless $IsTwosComplement

    for my $format (qw(s i l j s! i! l! q))
        :SKIP do
            my ($nat,$be,$le)
            try { (@: $nat,$be,$le) = (map: { (pack: $format.$_, -1) }, (@:  '', '>', '<')) }
            skip: "cannot pack '$format' on this perl", 15
                if is_valid_error: $^EVAL_ERROR

            my $len = length $nat
            for (@: $nat, $be, $le)
                is: $_, "\x[FF]"x$len

            my(@val,@ref)
            if ($len +>= 8)
                @val = @: -2, -81985529216486896, -9223372036854775808
                @ref = @: "\x[FFFFFFFFFFFFFFFE]"
                          "\x[FEDCBA9876543210]"
                          "\x[8000000000000000]"
            elsif ($len +>= 4)
                @val = @: -2, -19088744, -2147483648
                @ref = @: "\x[FFFFFFFE]"
                          "\x[FEDCBA98]"
                          "\x[80000000]"
            else
                @val = @: -2, -292, -32768
                @ref = @: "\x[FFFE]"
                          "\x[FEDC]"
                          "\x[8000]"
            
            for my $x ( @ref)
                if ($len +> length $x)
                    $x = $x . "\x[FF]" x ($len - length $x)
                
            

            for my $i (0 .. (nelems @val)-1)
                my (@: $nat,$be,$le) = try { (map: { (pack: $format.$_, @val[$i]) }, (@:  '', '>', '<')) }
                is: $^EVAL_ERROR, ''

                :SKIP do
                    skip: "cannot compare native byteorder with big-/little-endian", 1
                        if $ByteOrder eq 'unknown'

                    is: $nat, $ByteOrder eq 'big' ?? $be !! $le
                

                is: $be, @ref[$i]
                is: $be, ((join: '', (reverse:  (split: m//, $le))))
            
        
    


do
    # /

    my ($x, $y, $z)
    try { ($x) = (unpack: '/a*','hello') }
    like: $^EVAL_ERROR->{?description}, qr!'/' must follow a numeric type!
    undef $x
    try { $x = (unpack: '/a*','hello') }
    like: $^EVAL_ERROR->{?description}, qr!'/' must follow a numeric type!

    undef $x
    try { (@: $z,$x,$y) =(@:  (unpack: 'a3/A C/a* C/Z', "003ok \003yes\004z\000abc")) }
    is: $^EVAL_ERROR, ''
    is: $z, 'ok'
    is: $x, 'yes'
    is: $y, 'z'
    undef $z
    try { $z = (unpack: 'a3/A C/a* C/Z', "003ok \003yes\004z\000abc") }
    is: $^EVAL_ERROR, ''
    is: $z, 'ok'


    undef $x
    try { ($x) = (pack: '/a*','hello') }
    like: $^EVAL_ERROR->{?description},  qr!Invalid type '/'!
    undef $x
    try { $x = (pack: '/a*','hello') }
    like: $^EVAL_ERROR->{?description},  qr!Invalid type '/'!

    $z = pack: 'n/a* N/Z* w/A*','string','hi there ','etc'
    my $expect = "\000\006string\0\0\0\012hi there \000\003etc"
    is: $z, $expect

    undef $x
    $expect = 'hello world'
    try { ($x) = (unpack: "w/a", (chr: 11) . "hello world!")}
    is: $x, $expect
    is: $^EVAL_ERROR, ''

    undef $x
    # Doing this in scalar context used to fail.
    try { $x = (unpack: "w/a", (chr: 11) . "hello world!")}
    is: $^EVAL_ERROR, ''
    is: $x, $expect

    foreach (@:
           \(@: 'a/a*/a*', '212ab345678901234567','ab3456789012')
           \(@: 'a/a*/a*', '3012ab345678901234567', 'ab3456789012')
           \(@: 'a/a*/b*', '212ab', '100001100100')
        )
        my (@: $pat, $in, $expect) =  $_->@
        undef $x
        try { ($x) = (unpack: $pat, $in) }
        is: $^EVAL_ERROR, ''
        (is: $x, $expect) ||
            diag: sprintf: "list unpack ('$pat', '$in') gave \%s, expected '$expect'", <
                                    encode_list: $x

        undef $x
        try { $x = (unpack: $pat, $in) }
        is: $^EVAL_ERROR, ''
        (is: $x, $expect) ||
            diag: sprintf: "scalar unpack ('$pat', '$in') gave \%s, expected '$expect'", <
                                    encode_list: $x
    

    # / with #

    my $pattern = <<'EOU'
 a3/A			# Count in ASCII
 C/a*			# Count in a C char
 C/Z			# Count in a C char but skip after \0
EOU

    $x = $y = $z =undef
    try { (@: $z,$x,$y) =(@:  (unpack: $pattern, "003ok \003yes\004z\000abc")) }
    is: $^EVAL_ERROR, ''
    is: $z, 'ok'
    is: $x, 'yes'
    is: $y, 'z'
    undef $x
    try { $z = (unpack: $pattern, "003ok \003yes\004z\000abc") }
    is: $^EVAL_ERROR, ''
    is: $z, 'ok'

    $pattern = <<'EOP'
  n/a*			# Count as network short
  w/A*			# Count a  BER integer
EOP
    $expect = "\000\006string\003etc"
    $z = pack: $pattern,'string','etc'
    is: $z, $expect



:SKIP do
    use utf8 # for sprintf.
    is: "1.20.300.4000", (sprintf: "\%vd", (pack: "U*",1,20,300,4000))
    is: "1.20.300.4000", (sprintf: "\%vd", (pack: "  U*",1,20,300,4000))


do
    use utf8

    isnt: "\x{1}\x{14}\x{12c}\x{fa0}", (sprintf: "\%vd", (pack: "C0U*",1,20,300,4000))

    my $rslt = "199 162"
    is: (join: " ", (@:  (unpack: "C*", "\x{1e2}"))), $rslt

    # does pack U create Unicode?
    is: (pack: 'U', 0x300), "\x{300}"

    # does unpack U deref Unicode?
    is: (@: (unpack: 'U', "\x{300}"))[0], 0x300

    # is unpack U the reverse of pack U for Unicode string?
    is: "$((join: ' ', @: (unpack: 'U*', (pack: 'U*', 100, 200, 300))))", "100 200 300"

    # is unpack U the reverse of pack U for byte string?
    is: "$((join: ' ', @: (unpack: 'U*', (pack: 'U*', 100, 200))))", "100 200"


:SKIP do
    use utf8
    # does pack U0C create Unicode?
    is: "$((join: ' ', @: (pack: 'U0C*', 100, 195, 136)))", "\x{64}"."\x{c8}"

    # does pack C0U create characters?
    is: "$((join: ' ', @: (pack: 'C0U*', 100, 200)))", (pack: "C*", 100, 195, 136)

    # does unpack U0U on byte data warn?
    do
        use warnings < qw(NONFATAL all);;

        my $bad = pack: "U0C", 255
        local $^WARN_HOOK = sub (@< @_) { $^EVAL_ERROR = @_[0]; }
        my @null = @:  unpack: 'U0U', $bad 
        like: $^EVAL_ERROR->{?description}, qr/^Malformed UTF-8 character /
    


do
    my $p = pack: 'i*', -2147483648, ^~^0, 0, 1, 2147483647
    my (@a)
    # bug - % had to be at the start of the pattern, no leading whitespace or
    # comments. %i! didn't work at all.
    foreach my $pat ((@: '%32i*', ' %32i*', "# Muhahahaha\n\%32i*", '%32i*  '
                         '%32i!*', ' %32i!*', "\n#\n#\n\r \t\f\%32i!*", '%32i!*#'))
        @a = @:  unpack: $pat, $p 
        (is: @a[0], 0xFFFFFFFF) || diag: "$pat"
        @a = @:  scalar unpack: $pat, $p 
        (is: @a[0], 0xFFFFFFFF) || diag: "$pat"
    


    $p = pack: 'I*', 42, 12
    # Multiline patterns in scalar context failed.
    foreach my $pat ((@: 'I', <<EOPOEMSNIPPET, 'I#I', 'I # I', 'I # !!!'))
# On the Ning Nang Nong
# Where the Cows go Bong!
# And the Monkeys all say Boo!
I
EOPOEMSNIPPET
        @a = @:  unpack: $pat, $p 
        is: scalar nelems @a, 1
        is: @a[0], 42
        @a = @:  scalar unpack: $pat, $p 
        is: scalar nelems @a, 1
        is: @a[0], 42
    

    # shorts (of all flavours) didn't calculate checksums > 32 bits with floating
    # point, so a pathologically long pattern would wrap at 32 bits.
    my $pat = "\x[ffff]"x65538 # Start with it long, to save any copying.
    foreach ((@: 4,3,2,1,0))
        my $len = 65534 + $_
        is: (unpack: "\%33n$len", $pat), 65535 * $len
    



# pack x X @
foreach (@:
         \(@: 'x', "N", "\0")
         \(@: 'x4', "N", "\0"x4)
         \(@: 'xX', "N", "")
         \(@: 'xXa*', "Nick", "Nick")
         \(@: 'a5Xa5', "cameL", "llama", "camellama")
         \(@: '@4', 'N', "\0"x4)
         \(@: 'a*@8a*', 'Camel', 'Dromedary', "Camel\0\0\0Dromedary")
         \(@: 'a*@4a', 'Perl rules', '!', 'Perl!')
    )
    my (@: $template, @< @in) =  $_->@
    my $out = pop @in
    my $got = try {(pack: $template, < @in)}
    is: $^EVAL_ERROR, ''
    (is: $out, $got) ||
        diag: sprintf: "pack ('$template', \%s) gave \%s expected \%s"
                       < (encode_list: < @in), < (encode_list: $got), < encode_list: $out


# unpack x X @
foreach (@:
         \(@: 'x', "N")
         \(@: 'xX', "N")
         \(@: 'xXa*', "Nick", "Nick")
         \(@: 'a5Xa5', "camellama", "camel", "llama")
         \(@: '@3', "ice")
         \(@: '@2a2', "water", "te")
         \(@: 'a*@1a3', "steam", "steam", "tea")
    )
    my (@: $template, $in, @< @out) =  $_->@
    my @got = @:  try {(unpack: $template, $in)} 
    is: $^EVAL_ERROR, ''
    (ok: (list_eq: \@got, \@out)) ||
        diag: sprintf: "list unpack ('$template', \%s) gave \%s expected \%s", <
                                (_qq: $in), < (encode_list: < @got), < encode_list: < @out

    my $got = try {(unpack: $template, $in)}
    is: $^EVAL_ERROR, ''
    (nelems @out) ?? is:  $got, @out[0]  # 1 or more items; should get first
        !! ok:  !defined $got  # 0 items; should get undef
        or diag: printf: "scalar unpack ('$template', \%s) gave \%s expected \%s", <
                                     (_qq: $in), < (encode_list: $got), < encode_list: @out[0]


do
    my $t = 'Z*Z*'
    my (@: $u, $v) =  qw(foo xyzzy)
    my $p = pack: $t, $u, $v
    my @u = @:  unpack: $t, $p 
    is: scalar nelems @u, 2
    is: @u[0], $u
    is: @u[1], $v


do
    is: (@: (unpack: "w/a*", "\x[02]abc"))[0], "ab"

    # "w/a*" should be seen as one unit

    is: scalar (unpack: "w/a*", "\x[02]abc"), "ab"


:SKIP do
    info: "group modifiers"

    skip: $no_endianness, 3 * 2 + 3 * 2 + 1 if $no_endianness

    for my $t (qw{ (s<)< (sl>s)> (s(l(sl)<l)s)< })
        info: "testing pattern '$t'"
        try { ($_) = (unpack: $t, 'x'x18); }
        is: $^EVAL_ERROR, ''
        try { $_ = (pack: $t, (0)x6); }
        is: $^EVAL_ERROR, ''
    

    for my $t (qw{ (s<)> (sl>s)< (s(l(sl)<l)s)> })
        info: "testing pattern '$t'"
        try @: $_ = @: unpack: $t, 'x'x18
        like: $^EVAL_ERROR->{?description}, qr/Can't use '[<>]' in a group with different byte-order in unpack/
        try { $_ = (pack: $t, (0)x6); }
        like: $^EVAL_ERROR->{?description}, qr/Can't use '[<>]' in a group with different byte-order in pack/
    

    is: (pack: 'L<L>', (0x12345678)x2)
        (pack: '(((L1)1)<)(((L)1)1)>1', (0x12345678)x2)


do
    no utf8

    sub compress_template
        my $t = shift
        for my $mod (qw( < > ))
            $t =~ s/((?:(?:[SILQJFDP]!?$mod|[^SILQJFDP\W]!?)(?:\d+|\*|\[(?:[^]]+)\])?\/?)\{2,\})/$( do {
                my $x = $1; $x =~ s!$mod!!g ?? "($x)$mod" !! $x })/ig
        
        return $t
    

    my %templates = %:
        's<'                  => \(@: -42)
        's<c2x![S]S<'         => \(@: -42, -11, 12, 4711)
        '(i<j<[s]l<)3'        => \(@: -11, -22, -33, 1000000, 1100, 2201, 3302
                                      -1000000, 32767, -32768, 1, -123456789 )
        '(I!<4(J<2L<)3)5'     => \(1 .. 65)
        'q<Q<'                => \(@: -50000000005, 60000000006)
        'f<F<d<'              => \(@: 3.14159, 111.11, 2222.22)
        'D<cCD<'              => \(@: 1e42, -128, 255, 1e-42)
        'n/a*'                => \(@: '/usr/bin/perl')
        'C/a*S</A*L</Z*I</a*' => \qw(Just another Perl hacker)
        

    for my $tle ((sort: keys %templates))
        my @d = %templates{?$tle}->@
        my $tbe = $tle
        $tbe =~ s/</>/g
        for my $t ((@: $tbe, $tle))
            my $c = compress_template: $t
            info: "'$t' -> '$c'"
            :SKIP do
                my $p1 = try { (pack: $t, < @d) }
                skip: "cannot pack '$t' on this perl", 5 if is_valid_error: $^EVAL_ERROR
                my $p2 = try { (pack: $c, < @d) }
                is: $^EVAL_ERROR, ''
                is: $p1, $p2
                for (@: $t, $c)
                    s!(/[aAZ])\*!$1!g
                my @u1 = @:  try { (unpack: $t, $p1) } 
                is: $^EVAL_ERROR, ''
                my @u2 = @:  try { (unpack: $c, $p2) } 
                is: $^EVAL_ERROR, ''
                is: (join: '!', @u1), (join: '!', @u2)
            
        
    


do
    # from Wolfgang Laun: fix in change #13163

    my $s = 'ABC' x 10
    my $t = '*'
    my $x = ord: $t
    my $buf = pack:  'Z*/A* C',  $s, $x 
    my $y

    my $h = $buf
    $h =~ s/[^[:print:]]/./g
    (@:  $s, $y ) = @: unpack:  "Z*/A* C", $buf 
    is: $h, "30.ABCABCABCABCABCABCABCABCABCABC$t"
    is: length $buf, 34
    is: $s, "ABCABCABCABCABCABCABCABCABCABC"
    is: $y, $x


do
    # from Wolfgang Laun: fix in change #13288

    try { my $t=(unpack: "P*", "abc") }
    like: $^EVAL_ERROR->{?description}, qr/'P' must have an explicit size/


do   # Grouping constructs
    my (@a, @b)
    @a = @:  unpack: '(SL)',   pack: 'SLSLSL', < 67..90 
    is: "$((join: ' ',@a))", "67 68"
    @a = @:  unpack: '(SL)3',   pack: 'SLSLSL', < 67..90 
    @b =67..72
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)3',   pack: 'SLSLSLSL', < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)[3]', pack: 'SLSLSLSL', < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)[2] SL', pack: 'SLSLSLSL', < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: 'A/(SL)',  pack: 'ASLSLSLSL', 3, < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: 'A/(SL)SL',  pack: 'ASLSLSLSL', 2, < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)*',   pack: 'SLSLSLSL', < 67..90 
    @b =67..74
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)*SL',   pack: 'SLSLSLSL', < 67..90 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    try { @a = (@:  (unpack: '(*SL)',   '') ) }
    like: $^EVAL_ERROR->{?description}, qr/\(\)-group starts with a count/
    try { @a = (@:  (unpack: '(3SL)',   '') ) }
    like: $^EVAL_ERROR->{?description}, qr/\(\)-group starts with a count/
    try { @a = (@:  (unpack: '([3]SL)',   '') ) }
    like: $^EVAL_ERROR->{?description}, qr/\(\)-group starts with a count/
    try { @a = (@:  (pack: '(*SL)') ) }
    like: $^EVAL_ERROR->{?description}, qr/\(\)-group starts with a count/
    @a = @:  unpack: '(SL)3 SL',   pack: '(SL)4', < 67..74 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)3 SL',   pack: '(SL)[4]', < 67..74 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"
    @a = @:  unpack: '(SL)3 SL',   pack: '(SL)*', < 67..74 
    is: "$((join: ' ',@a))", "$((join: ' ',@b))"


do  # more on grouping (W.Laun)
    # @ absolute within ()-group
    my $badc = pack:  '(a)*', (unpack:  '(@1a @0a @2)*', 'abcd' ) 
    is:  $badc, 'badc' 
    my @b = @:  1, 2, 3 
    my $buf = pack:  '(@1c)((@2C)@3c)', < @b 
    is:  $buf, "\0\1\0\0\2\3" 
    my @a = @:  unpack:  '(@1c)((@2c)@3c)', $buf  
    is:  "$((join: ' ',@a))", "$((join: ' ',@b))" 

    # various unpack count/code scenarios
    my @Env = @:  a => 'AAA', b => 'BBB' 
    my $env = pack:  'S(S/A*S/A*)*', (nelems @Env)/2, < @Env 

    # unpack full length - ok
    my @pup = @:  unpack:  'S/(S/A* S/A*)', $env  
    is:  "$((join: ' ',@pup))", "$((join: ' ',@Env))" 

    # warn when count/code goes beyond end of string
    # \0002 \0001 a \0003 AAA \0001 b \0003 BBB
    #     2     4 5     7  10    1213
    try { @pup = (@:  (unpack:  'S/(S/A* S/A*)', (substr:  $env, 0, 13 ) ) ) }
    like:  $^EVAL_ERROR->{?description}, qr{length/code after end of string} 

    # postfix repeat count
    $env = pack:  '(S/A* S/A*)' . (nelems @Env)/2, < @Env 

    # warn when count/code goes beyond end of string
    # \0001 a \0003 AAA \0001  b \0003 BBB
    #     2 3c    5   8    10 11    13  16
    try { @pup = (@:  (unpack:  '(S/A* S/A*)' . (nelems @Env)/2, (substr:  $env, 0, 11 ) ) ) }
    like:  $^EVAL_ERROR->{?description}, qr{length/code after end of string} 

    # catch stack overflow/segfault
    try { $_ = (pack:  ('(' x 105) . 'A' . (')' x 105) ); }
    like:  $^EVAL_ERROR->{?description}, qr{Too deeply nested \(\)-groups} 


do # syntax checks (W.Laun)
    use warnings < qw(NONFATAL all);;
    my @warning
    local $^WARN_HOOK = sub (@< @_)
        push:  @warning, @_[0]->{?description} 
    
    try { my $s = (pack:  'Ax![4c]A', < 1..5 ); }
    like:  $^EVAL_ERROR->{?description}, qr{Malformed integer in \[\]} 

    try { my $buf = (pack:  '(c/*a*)', 'AAA', 'BB' ); }
    like:  $^EVAL_ERROR->{?description}, qr{'/' does not take a repeat count} 

    try { my @inf = (@:  (unpack:  'c/1a', "\x[03]AAA\x[02]BB" ) ); }
    like:  $^EVAL_ERROR->{?description}, qr{'/' does not take a repeat count} 

    try { my @inf = (@:  (unpack:  'c/*a', "\x[03]AAA\x[02]BB" ) ); }
    like:  $^EVAL_ERROR->{?description}, qr{'/' does not take a repeat count} 

    # white space where possible
    my @Env = @:  a => 'AAA', b => 'BBB' 
    my $env = pack:  ' S ( S / A*   S / A* )* ', (nelems @Env)/2, < @Env 
    my @pup = @:  unpack:  ' S / ( S / A*   S / A* ) ', $env  
    is:  "$((join: ' ',@pup))", "$((join: ' ',@Env))" 

    # white space in 4 wrong places
    for my $temp ((@:   'A ![4]', 'A [4]', 'A *', 'A 4') )
        try { my $s = (pack:  $temp, 'B' ); }
        like:  $^EVAL_ERROR->{?description}, qr{Invalid type } 
    

    # warning for commas
    @warning = $@
    my $x = pack:  'I,A', 4, 'X' 
    like:  @warning[0], qr{Invalid type ','} 

    # comma warning only once
    @warning = $@
    $x = pack:  'C(C,C)C,C', < 65..71  
    like:  scalar nelems @warning, 1 

    # forbidden code in []
    try { my $x = (pack:  'A[@4]', 'XXXX' ); }
    like:  $^EVAL_ERROR->{?description}, qr{Within \[\]-length '\@' not allowed} 

    # @ repeat default 1
    my $s = pack:  'AA@A', 'A', 'B', 'C' 
    my @c = @:  unpack:  'AA@A', $s  
    is:  $s, 'AC' 
    is:  "$((join: ' ',@c))", "A C C" 

    # no unpack code after /
    try { my @a = (@:  (unpack:  "C/", "\3" ) ); }
    like:  $^EVAL_ERROR->{?description}, qr{Code missing after '/'} 

    :SKIP do
        skip: $no_endianness, 6 if $no_endianness

        # modifier warnings
        @warning = $@
        $x = pack: "I>>s!!", 47, 11
        ($x) = unpack: "I<<l!>!>", 'x'x20
        is: scalar nelems @warning, 5
        like: @warning[0], qr/Duplicate modifier '>' after 'I' in pack/
        like: @warning[1], qr/Duplicate modifier '!' after 's' in pack/
        like: @warning[2], qr/Duplicate modifier '<' after 'I' in unpack/
        like: @warning[3], qr/Duplicate modifier '!' after 'l' in unpack/
        like: @warning[4], qr/Duplicate modifier '>' after 'l' in unpack/
    


do  # Repeat count [SUBEXPR]
    my @codes = qw( x A Z a c C W B b H h s v n S i I l V N L p P f F d
		   s! S! i! I! l! L! j J)
    my $G
    if (try { (pack: 'q', 1) } )
        push: @codes, < qw(q Q)
    else
        push: @codes, < qw(s S)	# Keep the count the same
    
    if (try { (pack: 'D', 1) } )
        push: @codes, 'D'
    else
        push: @codes, 'd'	# Keep the count the same
    

    push: @codes, < @+: map: { m/^[silqjfdp]/i ?? (@: "$_<", "$_>") !! $@ }, @codes

    my %val
    %val{[ @codes]} =  map: {
                                my (%:  1 => $v, ...) =
                                     %:  $( m/ [Xx] /x )=> undef
                                         $( m/ [AZa] /x )=> 'something'
                                         $( m/ C     /x )=> 214
                                         $( m/ W     /x )=> 188
                                         $( m/ c     /x )=> 114
                                         $( m/ [Bb]  /x )=> '101'
                                         $( m/ [Hh]  /x )=> 'b8'
                                         $( m/ [svnSiIlVNLqQjJ]  /x )=> 10111
                                         $( m/ [FfDd]  /x )=> 1.36514538e67
                                         $( m/ [pP]  /x )=> "try this buffer";
                                $v;
                              }, @codes
    my @end = @: 0x12345678, 0x23456781, 0x35465768, 0x15263748
    my $end = "N4"

    for my $type ( @codes)
        my @list = @:  %val{?$type} 
        @list = $@ unless defined @list[0]
        for my $count ((@: '', '3', '[11]'))
            my $c = 1
            $c = $1 if $count =~ m/(\d+)/
            my @list1 = @list
            @list1 = @list1 x $c unless $type =~ m/[XxAaZBbHhP]/
            for my $groupend ((@: '', ')2', ')[8]'))
                my $groupbegin = ($groupend ?? '(' !! '')
                $c = 1
                $c = $1 if $groupend =~ m/(\d+)/
                my @list2 = @list1 x $c 

                :SKIP do
                    my $junk1 = "$groupbegin $type$count $groupend"
                    info: "junk1=$junk1"
                    my $p = try { (pack: $junk1, < @list2) }
                    skip: "cannot pack '$type' on this perl", 12
                        if is_valid_error: $^EVAL_ERROR
                    die: "pack $junk1 failed: $($^EVAL_ERROR->message)" if $^EVAL_ERROR

                    my $half = int:  (length $p)/2 
                    for my $move ((@: '', "X$half", "X!$half", 'x1', 'x!8', "x$half"))
                        my $junk = "$junk1 $move"
                        info: "junk='$junk', end='$end' list=($((join: ', ', @list2)))"
                        $p = pack: "$junk $end", < @list2, < @end
                        my @l = @:  unpack: "x[$junk] $end", $p 
                        is: scalar nelems @l, scalar nelems @end
                        is: "$((join: ' ',@l))", "$((join: ' ',@end))", "skipping x[$junk]"
                    
                
            
        
    


# / is recognized after spaces in scalar context
# XXXX no spaces are allowed in pack...  In pack only before the slash...
is: scalar (unpack: 'A /A Z20', (pack: 'A/A* Z20', 'bcde', 'xxxxx')), 'bcde'
is: scalar (unpack: 'A /A /A Z20', '3004bcde'), 'bcde'

do # X! and x!
    my $t = 'C[3]  x!8 C[2]'
    my @a =0x73..0x77
    my $p = pack: $t, < @a
    is: $p, "\x[737475]\0\0\0\0\0\x[7677]"
    my @b = @:  unpack: $t, $p 
    is: scalar nelems @b, scalar nelems @a
    is: "$((join: ' ',@b))", "$((join: ' ',@a))", 'x!8'
    $t = 'x[5] C[6] X!8 C[2]'
    @a =0x73..0x7a
    $p = pack: $t, < @a
    is: $p, "\0\0\0\0\0\x[737475797a]"
    @b = @:  unpack: $t, $p 
    @a = @:  <0x73..0x75, 0x79, 0x7a, 0x79, 0x7a
    is: scalar nelems @b, scalar nelems @a
    is: "$((join: ' ',@b))", "$((join: ' ',@a))"


do # struct {char c1; double d; char cc[2];}
    my $t = 'C x![d] d C[2]'
    my @a = @: 173, 1.283476517e-45, 42, 215
    my $p = pack: $t, < @a
    ok:  length $p
    my @b = @:  unpack: "$t X[$t] $t", $p 	# Extract, step back, extract again
    is: scalar nelems @b, 2 * scalar nelems @a
    $b = "$((join: ' ',@b))"
    $b =~ s/(?:17000+|16999+)\d+(e-45) /17$1 /gi # stringification is gamble
    is: $b, "$((join: ' ',@a)) $((join: ' ',@a))"

    use warnings < qw(NONFATAL all);;
    my $warning
    local $^WARN_HOOK = sub (@< @_)
        $warning = @_[0]
    
    @b = @:  unpack: "x[C] x[$t] X[$t] X[C] $t", "$p\0" 

    is: $warning, undef
    is: scalar nelems @b, scalar nelems @a
    $b = "$((join: ' ',@b))"
    $b =~ s/(?:17000+|16999+)\d+(e-45) /17$1 /gi # stringification is gamble
    is: $b, "$((join: ' ',@a))"


is: (length: (pack: "j", 0)), (config_value: "ivsize")
is: (length: (pack: "J", 0)), (config_value: "uvsize")
is: (length: (pack: "F", 0)), (config_value: "nvsize")

numbers: 'j', -2147483648, -1, 0, 1, 2147483647
numbers: 'J', 0, 1, 2147483647, 2147483648, 4294967295
numbers: 'F', -(2**34), -1, 0, 1, 2**34
:SKIP do
    my $t = try { (unpack: "D*", (pack: "D", 12.34)) }

    skip: "Long doubles not in use", 166 if $^EVAL_ERROR->{?description} =~ m/Invalid type/

    is: (length: (pack: "D", 0)), (config_value: "longdblsize")
    numbers: 'D', -(2**34), -1, 0, 1, 2**34


# Maybe this knowledge needs to be "global" for all of pack.t
# Or a "can checksum" which would effectively be all the number types"
my %cant_checksum = %+: map: { %: $_=> 1 }, qw(A Z u w) 
# not a b B h H
foreach my $template (qw(A Z c C s S i I l L n N v V q Q j J f d F D u U w))
    :SKIP do
        my $packed = try {(pack: "$($template)4", 1, 4, 9, 16)}
        if ($^EVAL_ERROR)
            die: unless $^EVAL_ERROR->{?description} =~ m/Invalid type '$template'/
            skip: "$template not supported on this perl"
                  %cant_checksum{?$template} ?? 4 !! 8
        
        my @unpack4 = @:  unpack: "$($template)4", $packed 
        my @unpack = @:  unpack: "$($template)*", $packed 
        my @unpack1 = @:  unpack: "$($template)", $packed 
        my @unpack1s = @:  scalar unpack: "$($template)", $packed 
        my @unpack4s = @:  scalar unpack: "$($template)4", $packed 
        my @unpacks = @:  scalar unpack: "$($template)*", $packed 

        my @tests = @:  \(@: "$($template)4 vs $($template)*", \@unpack4, \@unpack)
                        \(@: "scalar $($template) $($template)", \@unpack1s, \@unpack1)
                        \(@: "scalar $($template)4 vs $($template)", \@unpack4s, \@unpack1)
                        \(@: "scalar $($template)* vs $($template)", \@unpacks, \@unpack1)
            

        unless (%cant_checksum{?$template})
            my @unpack4_c = @:  unpack: "\%$($template)4", $packed 
            my @unpack_c = @:  unpack: "\%$($template)*", $packed 
            my @unpack1_c = @:  unpack: "\%$($template)", $packed 
            my @unpack1s_c = @:  scalar unpack: "\%$($template)", $packed 
            my @unpack4s_c = @:  scalar unpack: "\%$($template)4", $packed 
            my @unpacks_c = @:  scalar unpack: "\%$($template)*", $packed 

            push: @tests
                  ( \(@: "\% $($template)4 vs $($template)*", \@unpack4_c, \@unpack_c),
                      \(@: "\% scalar $($template) $($template)", \@unpack1s_c, \@unpack1_c),
                      \(@: "\% scalar $($template)4 vs $($template)*", \@unpack4s_c, \@unpack_c),
                      \(@: "\% scalar $($template)* vs $($template)*", \@unpacks_c, \@unpack_c),
                      )
        
        foreach my $test ( @tests)
            (ok: (list_eq: $test->[1], $test->[2]), $test->[0]) ||
                diag: sprintf: "unpack gave \%s expected \%s", <
                                        (encode_list: < $test->[1]->@), < encode_list: < $test->[2]->@
        
    


ok: (pack: 'u2', 'AA'), "[perl #8026]" # used to hang and eat RAM in perl 5.7.2

$_ = pack: 'c', 65 # 'A' would not be EBCDIC-friendly
is: (unpack: 'c'), 65, "one-arg unpack (change #18751)" # defaulting to $_

do
    my $a = "X\x[09]01234567\n" x 100 # \t would not be EBCDIC TAB
    my @a = @:  unpack: "(a1 c/a)*", $a 
    is: scalar nelems @a, 200,       "[perl #15288]"
    is: @a[-1], "01234567\n", "[perl #15288]"
    is: @a[-2], "X",          "[perl #15288]"


do
    use warnings < qw(NONFATAL all);;
    my $warning
    local $^WARN_HOOK = sub (@< @_)
        $warning = @_[0]->message: 
    
    my $out = pack: "u99", "foo" x 99
    like: $warning, qr/Field too wide in 'u' format in pack/
          "Warn about too wide uuencode"
    is: $out, ("_" . "9F]O" x 21 . "\n") x 4 . "M" . "9F]O" x 15 . "\n"
        "Use max width in case of too wide uuencode"


# checksums
do
    # verify that unpack advances correctly wrt a checksum
    my (@: @x) =@:  (@:  (unpack: "b10a", "abcd") )
    my (@: @y) =@:  (@:  (unpack: "\%b10a", "abcd") )
    is: @x[1], @y[1], "checksum advance ok"

    # verify that the checksum is not overflowed with C0
    if ((ord: 'A') == 193)
        is: (unpack: "C0\%128U", "/bcd"), (unpack: "U0\%128U", "abcd"), "checksum not overflowed"
    else
        is: (unpack: "C0\%128U", "abcd"), (unpack: "U0\%128U", "abcd"), "checksum not overflowed"
    


do
    # U0 and C0 must be scoped
    my (@: @x) =@:  (@:  (unpack: "a(U0)U", "b\341\277\274") )
    is: @x[0], 'b', 'before scope'
    is: @x[1], 8188, 'after scope'

    is: (pack: "a(U0)U", "b", 8188), "b\341\277\274"


do
    # counted length prefixes shouldn't change C0/U0 mode
    # (note the length is actually 0 in this test)
    is: (join: ',', (@:  (unpack: "aC/UU",   "b\0\341\277\274"))), 'b,8188'
    is: (join: ',', (@:  (unpack: "aC/CU",   "b\0\341\277\274"))), 'b,8188'
    is: (join: ',', (@:  (unpack: "aU0C/UU", "b\0\341\277\274"))), 'b,8188'
    is: (join: ',', (@:  (unpack: "aU0C/CU", "b\0\341\277\274"))), 'b,8188'


do
    # "Z0" (bug #34062)
    my (@: @x) =@:  (@:  (unpack: "C*", (pack: "CZ0", 1, "b")) )
    is: (join: ',', @x), '1', q|pack Z0 doesn't destroy the character before|


do
    # Encoding neutrality
    # String we will pull apart and rebuild in several ways:
    my $down = "\x[f8f9fafbfcfdfeff0506]"
    my $up   = $down
    utf8::encode: $up

    my %expect =
        # [expected result,
        #  how many chars it should progress,
        #  (optional) expected result of pack]
        %: a5 => \(@: "\x[f8f9fafbfc]", 5)
           A5 => \(@: "\x[f8f9fafbfc]", 5)
           Z5 => \(@: "\x[f8f9fafbfc]", 5, "\x[f8f9fafb00fd]")
           b21 => \(@: "000111111001111101011", 3, "\x[f8f91afb]")
           B21 => \(@: "111110001111100111111", 3, "\x[f8f9f8fb]")
           H5 => \(@: "f8f9f", 3, "\x[f8f9f0fb]")
           h5 => \(@: "8f9fa", 3, "\x[f8f90afb]")
           "s<"  => \(@: -1544, 2)
           "s>"  => \(@: -1799, 2)
           "S<"  => \(@: 0xf9f8, 2)
           "S>"  => \(@: 0xf8f9, 2)
           "l<"  => \(@: -67438088, 4)
           "l>"  => \(@: -117835013, 4)
           "L>"  => \(@: 0xf8f9fafb, 4)
           "L<"  => \(@: 0xfbfaf9f8, 4)
           n     => \(@: 0xf8f9, 2)
           N     => \(@: 0xf8f9fafb, 4)
           v     => \(@: 63992, 2)
           V     => \(@: 0xfbfaf9f8, 4)
           c     => \(@: -8, 1)
           # (invalid unicode) U0U   => \@(0xf8, 1),
           w     => \(@: "8715569050387726213", 9)
           q     => \(@: "-283686952306184", 8)
           Q     => \(@: "18446460386757245432", 8)
        

    for my $string ((@: $down, $up))
        for my $format ((sort: {(lc: $a) cmp (lc: $b) || $a cmp $b }, keys %expect))
            :SKIP do
                my $expect = %expect{?$format}
                # unpack upgraded and downgraded string
                my @result = @:  try { (unpack: "$format C0 W", $string) } 
                skip: "cannot pack/unpack '$format C0 W' on this perl", 5 if
                      $^EVAL_ERROR && is_valid_error: $^EVAL_ERROR
                is: $^EVAL_ERROR, '', "no errors"
                is: (nelems @result), 2, "Two results from unpack $format C0 W"

                # pack to downgraded
                my $new = pack: "$format C0 W", < @result
                is: (length: $new), $expect->[1]+1
                    "pack $format C0 W should give $expect->[1]+1 chars"
                is: $new, $expect->[?2] || (substr: $string, 0, length $new)
                    "pack $format C0 W returns expected value"

                # pack to upgraded
                $new = pack: "a0 $format C0 W", (utf8::chr: 256), < @result
                is: (length: $new), $expect->[1]+1
                    "pack a0 $format C0 W should give $expect->[1]+1 chars"
                is: $new, $expect->[?2] || (substr: $string, 0, length $new)
                    "pack a0 $format C0 W returns expected value"
            
        
    


do
    # use utf8 neutrality, numbers
    for (@:  ( < map: { \(@: $_, -2.68) }, qw(s S i I l L j J f d F D q Q
                                   s! S! i! I! l! L! n! N! v! V!))
             \(@: 'C', 253), \(@: 'u', "\x[f8f9fafbfcfdfeff0506]")
             \(@: 'U', 0x300), \(@: 'a3', "abc"), \(@: 'a0', '')
             \(@: 'A3', "abc"), \(@: 'Z3', "ghi")
        )
        :SKIP do
            my (@: $format, $val) =  $_->@
            no utf8;
            my $down = try { (pack: $format, $val) }
            skip: "cannot pack/unpack $format on this perl", 9 if
                  $^EVAL_ERROR && is_valid_error: $^EVAL_ERROR
            use utf8
            my $up = pack: "$format", $val
            is: $down, $up, "$format generated strings are equal though"
            no utf8;
            my @down_expanded = @:  unpack: "$format W", $down . (chr: 0x66) 
            is: (nelems @down_expanded), 2, "Expand to two values"
            is: @down_expanded[1], 0x66
                "unpack $format left us at the expected position"
            use utf8
            my @up_expanded   = @:  unpack: "$format W", $up   . (chr: 0x66) 
            is: (nelems @up_expanded), 2, "Expand to two values"
            is: @up_expanded[1], 0x66
                "unpack $format left us at the expected position"
            is: @down_expanded[0], @up_expanded[0], "$format unpack was neutral"
            is: (pack: $format, @down_expanded[0]), $down, "Pack $format undoes unpack $format"
        
    


do
    # Harder cases for the neutrality test

    # u format
    my $down = "\x[f8f9fafbfcfdfeff0506]"
    my $up   = $down
    utf8::encode: $up
    is: (pack: "u", $down), (pack: "u", $up), "u pack is neutral"
    is: (unpack: "u", (pack: "u", $down)), $down, "u unpack to downgraded works"
    is: (unpack: "U0C0u", (pack: "u", $down)), $up, "u unpack to upgraded works"

    # p/P format
    # This actually only tests something if the address contains a byte >= 0x80
    my $str = "abc\x[a500fe]de"
    $down = pack: "p", $str
    is: (pack: "P", $str), $down
    is: (pack: "U0C0p", $str), $down
    is: (pack: "U0C0P", $str), $down
    is: (unpack: "p", $down), "abc\x[a5]", "unpack p downgraded"
    $up   = $down
    utf8::encode: $up
    is: (unpack: "p", $up), "abc\x[a5]", "unpack p upgraded"

    is: (unpack: "P7", $down), "abc\x[a500fe]d", "unpack P downgraded"
    is: (unpack: "P7", $up),   "abc\x[a500fe]d", "unpack P upgraded"

    # x, X and @
    $down = "\x[f8f9fafbfcfdfeff0506]"
    $up   = $down
    utf8::encode: $up

    is: (unpack: '@4W', $down), 0xfc, "\@positioning on downgraded string"
    is: (unpack: '@4W', $up),   0xfc, "\@positioning on upgraded string"

    is: (unpack: '@4x2W', $down), 0xfe, "x moving on downgraded string"
    is: (unpack: '@4x2W', $up),   0xfe, "x moving on upgraded string"
    is: (unpack: '@4x!4W', $down), 0xfc, "x! moving on downgraded string"
    is: (unpack: '@4x!4W', $up),   0xfc, "x! moving on upgraded string"
    is: (unpack: '@5x!4W', $down), 0x05, "x! moving on downgraded string"
    is: (unpack: '@5x!4W', $up),   0x05, "x! moving on upgraded string"

    is: (unpack: '@4X2W', $down), 0xfa, "X moving on downgraded string"
    is: (unpack: '@4X2W', $up),   0xfa, "X moving on upgraded string"
    is: (unpack: '@4X!4W', $down), 0xfc, "X! moving on downgraded string"
    is: (unpack: '@4X!4W', $up),   0xfc, "X! moving on upgraded string"
    is: (unpack: '@5X!4W', $down), 0xfc, "X! moving on downgraded string"
    is: (unpack: '@5X!4W', $up),   0xfc, "X! moving on upgraded string"
    is: (unpack: '@5X!8W', $down), 0xf8, "X! moving on downgraded string"
    is: (unpack: '@5X!8W', $up),   0xf8, "X! moving on upgraded string"

    is: (pack: "W2x", 0xfa, 0xe3), "\x[fae300]", "x on downgraded string"
    is: (pack: "W2x!4", 0xfa, 0xe3), "\x[fae30000]"
        "x! on downgraded string"
    is: (pack: "W2x!2", 0xfa, 0xe3), "\x[fae3]", "x! on downgraded string"
    is: (pack: "W2x", 0xfa, 0xe3), "\x[fae300]", "x on upgraded string"
    is: (pack: "W2x!4", 0xfa, 0xe3), "\x[fae30000]"
        "x! on upgraded string"
    is: (pack: "W2x!2", 0xfa, 0xe3), "\x[fae3]", "x! on upgraded string"
    is: (pack: "W2X", 0xfa, 0xe3), "\x[fa]", "X on downgraded string"
    is: (pack: "W2X!2", 0xfa, 0xe3), "\x[fae3]", "X! on downgraded string"
    is: (pack: "W3X!2", 0xfa, 0xe3, 0xa6), "\x[fae3]", "X! on downgraded string"

    # backward eating through a ( moves the group starting point backwards
    is: (pack: "a*(Xa)", "abc", "q"), "abq"
        "eating before strbeg moves it back"
    do
        use utf8
        is: (pack: "a*(Xa)", "ab" . (chr: 512), "q"), "abq"
            "eating before strbeg moves it back # TODO use utf8 on pack?!"
    


do
    # pack /
    my @array = 1..14
    my @out = @:  unpack: "N/S", (pack: "N/S", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "$((join: ' ',@array))", "pack N/S works"
    @out = @:  unpack: "N/S*", (pack: "N/S*", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "$((join: ' ',@array))", "pack N/S* works"
    @out = @:  unpack: "N/S*", (pack: "N/S14", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "$((join: ' ',@array))", "pack N/S14 works"
    @out = @:  unpack: "N/S*", (pack: "N/S15", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "$((join: ' ',@array))", "pack N/S15 works"
    @out = @:  unpack: "N/S*", (pack: "N/S13", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "$((join: ' ', @array[[0..12]]))", "pack N/S13 works"
    @out = @:  unpack: "N/S*", (pack: "N/S0", < @array) . "abcd" 
    is: "$((join: ' ',@out))", "", "pack N/S0 works"
    is: (pack: "Z*/a0", "abc"), "0\0", "pack Z*/a0 makes a short string"
    is: (pack: "Z*/Z0", "abc"), "0\0", "pack Z*/Z0 makes a short string"
    is: (pack: "Z*/a3", "abc"), "3\0abc", "pack Z*/a3 makes a full string"
    is: (pack: "Z*/Z3", "abc"), "3\0ab\0", "pack Z*/Z3 makes a short string"
    is: (pack: "Z*/a5", "abc"), "5\0abc\0\0", "pack Z*/a5 makes a long string"
    is: (pack: "Z*/Z5", "abc"), "5\0abc\0\0", "pack Z*/Z5 makes a long string"
    is: (pack: "Z*/Z"), "1\0\0", "pack Z*/Z makes an extended string"
    is: (pack: "Z*/Z", ""), "1\0\0", "pack Z*/Z makes an extended string"
    is: (pack: "Z*/a", ""), "0\0", "pack Z*/a makes an extended string"

do
    use utf8
    local our $TODO = undef
    $TODO = "find out what pack('A*') is supposed to do"

    # unpack("A*", $unicode) strips general unicode spaces
    is: (unpack: "A*", "ab \n\x{a0} \0"), "ab \n\x{a0}"
        'normal A* strip leaves \x{a0}'
    is: (unpack: "U0C0A*", "ab \n\x{a0} \0"), "ab \n\x{a0}"
        'normal A* strip leaves \x{a0} even if it got upgraded for technical reasons'
    is: (unpack: "A*", (pack: "a*(U0U)a*", "ab \n", 0xa0, " \0")), "ab"
        'upgraded strings A* removes \x{a0}'
    is: (unpack: "A*", (pack: "a*(U0UU)a*", "ab \n", 0xa0, 0x1680, " \0")), "ab\x{0a}\x{1680}"
        'upgraded strings A* removes all unicode whitespace'
    is: (unpack: "A5", (pack: "a*(U0U)a*", "ab \n", 0x1680, "def", "ab")), "ab"
        'upgraded strings A5 removes all unicode whitespace'
    is: (unpack: "A*", (pack: "U", 0x1680)), ""
        'upgraded strings A* with nothing left'

do
    use utf8
    # Testing unpack . and .!
    is: (unpack: ".", "ABCD"), 0, "offset at start of string is 0"
    is: (unpack: ".", ""), 0, "offset at start of empty string is 0"
    is: (unpack: "x3.", "ABCDEF"), 3, "simple offset works"
    is: (unpack: "x3.", "ABC"), 3, "simple offset at end of string works"
    is: (unpack: "x3.0", "ABC"), 0, "self offset is 0"
    is: (unpack: "x3(x2.)", "ABCDEF"), 2, "offset is relative to inner group"
    is: (unpack: "x3(X2.)", "ABCDEF"), -2
        "negative offset relative to inner group"
    is: (unpack: "x3(X2.2)", "ABCDEF"), 1, "offset is relative to inner group"
    is: (unpack: "x3(x2.0)", "ABCDEF"), 0, "self offset in group is still 0"
    is: (unpack: "x3(x2.2)", "ABCDEF"), 5, "offset counts groups"
    is: (unpack: "x3(x2.*)", "ABCDEF"), 5, "star offset is relative to start"

    my $high = (chr: 8188) x 6
    is: (unpack: "x3(x2.)", $high), 2, "utf8 offset is relative to inner group"
    is: (unpack: "x3(X2.)", $high), -2
        "utf8 negative offset relative to inner group"
    is: (unpack: "x3(X2.2)", $high), 1, "utf8 offset counts groups"
    is: (unpack: "x3(x2.0)", $high), 0, "utf8 self offset in group is still 0"
    is: (unpack: "x3(x2.2)", $high), 5, "utf8 offset counts groups"
    is: (unpack: "x3(x2.*)", $high), 5, "utf8 star offset is relative to start"

    is: (unpack: "U0x3(x2.)", $high), 2
        "U0 mode utf8 offset is relative to inner group"
    is: (unpack: "U0x3(X2.)", $high), -2
        "U0 mode utf8 negative offset relative to inner group"
    is: (unpack: "U0x3(X2.2)", $high), 1
        "U0 mode utf8 offset counts groups"
    is: (unpack: "U0x3(x2.0)", $high), 0
        "U0 mode utf8 self offset in group is still 0"
    is: (unpack: "U0x3(x2.2)", $high), 5
        "U0 mode utf8 offset counts groups"
    is: (unpack: "U0x3(x2.*)", $high), 5
        "U0 mode utf8 star offset is relative to start"

    local our $TODO = "find out what this is supposed to do"
    is: (unpack: "x3(x2.!)", $high), 2*3
        "utf8 offset is relative to inner group"
    is: (unpack: "x3(X2.!)", $high), -2*3
        "utf8 negative offset relative to inner group"
    is: (unpack: "x3(X2.!2)", $high), 1*3
        "utf8 offset counts groups"
    is: (unpack: "x3(x2.!0)", $high), 0
        "utf8 self offset in group is still 0"
    is: (unpack: "x3(x2.!2)", $high), 5*3
        "utf8 offset counts groups"
    is: (unpack: "x3(x2.!*)", $high), 5*3
        "utf8 star offset is relative to start"

    is: (unpack: "U0x3(x2.!)", $high), 2
        "U0 mode utf8 offset is relative to inner group"
    is: (unpack: "U0x3(X2.!)", $high), -2
        "U0 mode utf8 negative offset relative to inner group"
    is: (unpack: "U0x3(X2.!2)", $high), 1
        "U0 mode utf8 offset counts groups"
    is: (unpack: "U0x3(x2.!0)", $high), 0
        "U0 mode utf8 self offset in group is still 0"
    is: (unpack: "U0x3(x2.!2)", $high), 5
        "U0 mode utf8 offset counts groups"
    is: (unpack: "U0x3(x2.!*)", $high), 5
        "U0 mode utf8 star offset is relative to start"

do
    # Testing pack . and .!
    is: (pack: "(a)5 .", < 1..5, 3), "123", ". relative to string start, shorten"
    try { (@: ...) = @: (pack: "(a)5 .", < 1..5, -3) }
    like: $^EVAL_ERROR->{?description}, qr{'\.' outside of string in pack}, "Proper error message"
    is: (pack: "(a)5 .", < 1..5, 8), "12345\0\0\0"
        ". relative to string start, extend"
    is: (pack: "(a)5 .", < 1..5, 5), "12345", ". relative to string start, keep"

    is: (pack: "(a)5 .0", < 1..5, -3), "12"
        ". relative to string current, shorten"
    is: (pack: "(a)5 .0", < 1..5, 2), "12345\0\0"
        ". relative to string current, extend"
    is: (pack: "(a)5 .0", < 1..5, 0), "12345"
        ". relative to string current, keep"

    is: (pack: "(a)5 (.)", < 1..5, -3), "12"
        ". relative to group, shorten"
    is: (pack: "(a)5 (.)", < 1..5, 2), "12345\0\0"
        ". relative to group, extend"
    is: (pack: "(a)5 (.)", < 1..5, 0), "12345"
        ". relative to group, keep"

    is: (pack: "(a)3 ((a)2 .)", < 1..5, -2), "1"
        ". relative to group, shorten"
    is: (pack: "(a)3 ((a)2 .)", < 1..5, 2), "12345"
        ". relative to group, keep"
    is: (pack: "(a)3 ((a)2 .)", < 1..5, 4), "12345\0\0"
        ". relative to group, extend"

    is: (pack: "(a)3 ((a)2 .2)", < 1..5, 2), "12"
        ". relative to counted group, shorten"
    is: (pack: "(a)3 ((a)2 .2)", < 1..5, 7), "12345\0\0"
        ". relative to counted group, extend"
    is: (pack: "(a)3 ((a)2 .2)", < 1..5, 5), "12345"
        ". relative to counted group, keep"

    is: (pack: "(a)3 ((a)2 .*)", < 1..5, 2), "12"
        ". relative to start, shorten"
    is: (pack: "(a)3 ((a)2 .*)", < 1..5, 7), "12345\0\0"
        ". relative to start, extend"
    is: (pack: "(a)3 ((a)2 .*)", < 1..5, 5), "12345"
        ". relative to start, keep"

    is: (pack: '(a)5 (. @2 a)', < 1..5, -3, "a"), "12\0\0a"
        ". based shrink properly updates group starts"

do
    use utf8
    # Testing @!
    is: (pack: 'a* @3',  "abcde"), "abc", 'Test basic @'
    is: (pack: 'a* @!3', "abcde"), "abc", 'Test basic @!'
    is: (pack: 'a* @2', "\x{301}\x{302}\x{303}\x{304}\x{305}"), "\x{301}\x{302}"
        'Test basic utf8 @'
    is: (pack: 'a* @!2', "\x{301}\x{302}\x{303}\x{304}\x{305}"), "\x{301}"
        'Test basic utf8 @!'

    is: (unpack: '@4 a*',  "abcde"), "e", 'Test basic @'
    is: (unpack: '@!4 a*', "abcde"), "e", 'Test basic @!'
    is: (unpack: '@4 a*',  "\x{301}\x{302}\x{303}\x{304}\x{305}"), "\x{303}\x{304}\x{305}"
        'Test basic utf8 @'
    is: (unpack: '@!4 a*', "\x{301}\x{302}\x{303}\x{304}\x{305}")
        "\x{303}\x{304}\x{305}", 'Test basic utf8 @!'

do
    #50256
    my (@: $v) =  split: m//, unpack: '(B)*', 'ab'
    is: $v, 0 # Doesn't SEGV :-)

