#!./perl

my $has_perlio

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 
    require './test.pl'
    unless ($has_perlio = (PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, <<EOF
# Since you don't have perlio you might get failures with UTF-8 locales.
EOF
    


no utf8 # Ironic, no?

# NOTE!
#
# Think carefully before adding tests here.  In general this should be
# used only for about three categories of tests:
#
# (1) tests that absolutely require 'use utf8', and since that in general
#     shouldn't be needed as the utf8 is being obsoleted, this should
#     have rather few tests.  If you want to test Unicode and regexes,
#     you probably want to go to op/regexp or op/pat; if you want to test
#     split, go to op/split; pack, op/pack; appending or joining,
#     op/append or op/join, and so forth
#
# (2) tests that have to do with Unicode tokenizing (though it's likely
#     that all the other Unicode tests sprinkled around the t/**/*.t are
#     going to catch that)
#
# (3) complicated tests that simultaneously stress so many Unicode features
#     that deciding into which other test script the tests should go to
#     is hard -- maybe consider breaking up the complicated test
#
#

plan: tests => 36

do
    # bug id 20000730.004
    use utf8

    my $smiley = "\x{263a}"

    for my $s (@: "\x{263a}"
                  $smiley

                  "" . $smiley
                  "" . "\x{263a}"

                  $smiley    . ""
                  "\x{263a}" . ""
        )
        my $length_chars = length: $s
        my $length_bytes
        do { use bytes; $length_bytes = (length: $s) }
        my @regex_chars = @:  $s =~ m/(.)/g 
        my $regex_chars = (nelems @regex_chars)
        my @split_chars = split: m//, $s
        my $split_chars = (nelems @split_chars)
        ok: "$length_chars/$regex_chars/$split_chars/$length_bytes" eq
               "1/1/1/3"
    

    for my $s (@: "\x{263a}" . "\x{263a}"
                  $smiley    . $smiley

                  "\x{263a}\x{263a}"
                  "$smiley$smiley"

                  "\x{263a}" x 2
                  $smiley    x 2
        )
        my $length_chars = length: $s
        my $length_bytes
        do { use bytes; $length_bytes = (length: $s) }
        my @regex_chars = @:  $s =~ m/(.)/g 
        my $regex_chars = (nelems @regex_chars)
        my @split_chars = split: m//, $s
        my $split_chars = (nelems @split_chars)
        ok: "$length_chars/$regex_chars/$split_chars/$length_bytes" eq
               "2/2/2/6"
    



do
    local our $TODO = "use utf8; passed to eval"
    use utf8;
    my $w = 0
    local $^WARN_HOOK = sub (@< @_) { (print: $^STDOUT, "#(@_[0])\n"); $w++ }
    my $x = eval q/"\\/ . "\x{100}" . q/"/

    ok: $w == 0 && $x eq "\x{100}"


#
# bug fixed by change #17928
# separate perl used because we rely on 'strict' not yet loaded;
# before the patch, the eval died with an error like:
#   "my" variable $strict::VERSION can't be in a package
#
:SKIP do
    skip: "Embedded UTF-8 does not work in EBCDIC", 1 if (ord: "A") == 193
    ok: '' eq (runperl: prog => <<'CODE'), "change #17928"
        my $code = qq{ my \$\xe3\x83\x95\xe3\x83\xbc = 5; };
    {
        use utf8;
        eval $code;
        print $@ if $@;
    }
CODE


do
    use utf8
    $a = <<'END'
0 ....... 1 ....... 2 ....... 3 ....... 4 ....... 5 ....... 6 ....... 7 ....... 
END
    my (@i, $s)

    @i = $@
    push: @i, ($s = (index: $a, '6'))     # 60
    push: @i, ($s = (index: $a, '.', $s)) # next . after 60 is 62
    push: @i, ($s = (index: $a, '5'))     # 50
    push: @i, ($s = (index: $a, '.', $s)) # next . after 52 is 52
    push: @i, ($s = (index: $a, '7'))     # 70
    push: @i, ($s = (index: $a, '.', $s)) # next . after 70 is 72
    push: @i, ($s = (index: $a, '4'))     # 40
    push: @i, ($s = (index: $a, '.', $s)) # next . after 40 is 42
    is: "$((join: ' ',@i))", "60 62 50 52 70 72 40 42", "utf8 heredoc index"

    @i = $@
    push: @i, ($s = (rindex: $a, '6'))     # 60
    push: @i, ($s = (rindex: $a, '.', $s)) # previous . before 60 is 58
    push: @i, ($s = (rindex: $a, '5'))     # 50
    push: @i, ($s = (rindex: $a, '.', $s)) # previous . before 52 is 48
    push: @i, ($s = (rindex: $a, '7'))     # 70
    push: @i, ($s = (rindex: $a, '.', $s)) # previous . before 70 is 68
    push: @i, ($s = (rindex: $a, '4'))     # 40
    push: @i, ($s = (rindex: $a, '.', $s)) # previous . before 40 is 38
    is: "$((join: ' ',@i))", "60 58 50 48 70 68 40 38", "utf8 heredoc rindex"

    @i = $@
    push: @i, ($s =  (index: $a, '6'))     # 60
    push: @i,  index: $a, '.', $s      # next     . after  60 is 62
    push: @i, rindex: $a, '.', $s      # previous . before 60 is 58
    push: @i, ($s = (rindex: $a, '5'))     # 60
    push: @i,  index: $a, '.', $s      # next     . after  50 is 52
    push: @i, rindex: $a, '.', $s      # previous . before 50 is 48
    push: @i, ($s =  (index: $a, '7', $s)) # 70
    push: @i,  index: $a, '.', $s      # next     . after  70 is 72
    push: @i, rindex: $a, '.', $s      # previous . before 70 is 68
    is: "$((join: ' ',@i))", "60 62 58 50 52 48 70 72 68", "utf8 heredoc index and rindex"


:SKIP do
    skip: "Embedded UTF-8 does not work in EBCDIC", 1 if (ord: "A") == 193
    use utf8;
    eval qq{is(q \xc3\xbc test \xc3\xbc, qq\xc2\xb7 test \xc2\xb7,
               "utf8 quote delimiters [perl #16823]");}


# Test the "internals".

do
    use utf8
    my $a = "A"
    my $b = chr: 0x0FF
    my $c = chr: 0x100

    ok:  (utf8::valid: $a), "utf8::valid basic"
    ok:  (utf8::valid: $b), "utf8::valid beyond"
    ok:  (utf8::valid: $c), "utf8::valid unicode"

    is: $a, "A",       "basic"
    is: $b, "\x{FF}",    "beyond"
    is: $c, "\x{100}", "unicode"

    # noop
    utf8::encode: $a
    utf8::encode: $b
    utf8::encode: $c

    is: $a, "A",       "basic"
    is: $b, "\x{FF}",    "beyond"
    is: $c, "\x{100}", "unicode"

    # noop
    utf8::decode: $a
    utf8::decode: $b
    utf8::decode: $c

    is: $a, "A",       "basic"
    is: $b, "\x{FF}",    "beyond"
    is: $c, "\x{100}", "unicode"


do
    use utf8
    try {(utf8::encode: "£")}
    is: $^EVAL_ERROR, '', "utf8::encode is a NO-OP"


do
    fresh_perl_like: 'use utf8; utf8::moo()'
                     qr/Undefined subroutine &utf8::moo/, \(%: stderr=>1)
                     "Check Carp is loaded for AUTOLOADing errors"


do
    # failure of is_utf8_char() without NATIVE_TO_UTF on EBCDIC (0260..027F)
    use utf8
    ok: (utf8::valid: (chr: 0x250)), "0x250"
    ok: (utf8::valid: (chr: 0x260)), "0x260"
    ok: (utf8::valid: (chr: 0x270)), "0x270"
    ok: (utf8::valid: (chr: 0x280)), "0x280"

