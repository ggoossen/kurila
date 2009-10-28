#!./perl

BEGIN 
    require './test.pl'


plan: tests => 56

our (@foo, $foo, $c, @bar, $got, %chop, %chomp, $x, $y)

$_ = 'abc'
$c =( foo: )
is: $c . $_, 'cab', 'optimized'

$_ = 'abc'
$c = chop: $_
is: $c . $_ , 'cab', 'unoptimized'

sub foo
    chop


@foo = @: "hi \n","there\n","!\n"
@bar = @foo
chop: @bar
is: (join: '', @bar), 'hi there!'

$_ = "foo\n\n"
$got = chomp: 
ok: $got == 1 or print: $^STDOUT, "# got $got\n"
is: $_, "foo\n"

$_ = "foo\n"
$got = chomp: 
ok: $got == 1 or print: $^STDOUT, "# got $got\n"
is: $_, "foo"

$_ = "foo"
$got = chomp: 
ok: $got == 0 or print: $^STDOUT, "# got $got\n"
is: $_, "foo"

$_ = "foo"
$^INPUT_RECORD_SEPARATOR = "oo"
$got = chomp: 
ok: $got == 2 or print: $^STDOUT, "# got $got\n"
is: $_, "f"

$_ = "bar"
$^INPUT_RECORD_SEPARATOR = "oo"
$got = chomp: 
ok: $got == 0 or print: $^STDOUT, "# got $got\n"
is: $_, "bar"

$_ = "f\n\n\n\n\n"
$^INPUT_RECORD_SEPARATOR = ""
$got = chomp: 
ok: $got == 5 or print: $^STDOUT, "# got $got\n"
is: $_, "f"

$_ = "f\n\n"
$^INPUT_RECORD_SEPARATOR = ""
$got = chomp: 
ok: $got == 2 or print: $^STDOUT, "# got $got\n"
is: $_, "f"

$_ = "f\n"
$^INPUT_RECORD_SEPARATOR = ""
$got = chomp: 
ok: $got == 1 or print: $^STDOUT, "# got $got\n"
is: $_, "f"

$_ = "f"
$^INPUT_RECORD_SEPARATOR = ""
$got = chomp: 
ok: $got == 0 or print: $^STDOUT, "# got $got\n"
is: $_, "f"

$_ = "xx"
$^INPUT_RECORD_SEPARATOR = "xx"
$got = chomp: 
ok: $got == 2 or print: $^STDOUT, "# got $got\n"
is: $_, ""

$_ = "axx"
$^INPUT_RECORD_SEPARATOR = "xx"
$got = chomp: 
ok: $got == 2 or print: $^STDOUT, "# got $got\n"
is: $_, "a"

$_ = "axx"
$^INPUT_RECORD_SEPARATOR = "yy"
$got = chomp: 
ok: $got == 0 or print: $^STDOUT, "# got $got\n"
is: $_, "axx"

# This case once mistakenly behaved like paragraph mode.
$_ = "ab\n"
$^INPUT_RECORD_SEPARATOR = \3
$got = chomp: 
ok: $got == 0 or print: $^STDOUT, "# got $got\n"
is: $_, "ab\n"

# Go Unicode.

do
    use utf8

    $_ = "abc\x{1234}"
    chop
    is: $_, "abc", "Go Unicode"

    $_ = "abc\x{1234}d"
    chop
    is: $_, "abc\x{1234}"

    $_ = "\x{1234}\x{2345}"
    chop
    is: $_, "\x{1234}"



# chomp should not stringify references unless it decides to modify them
$_ = \$@
$^INPUT_RECORD_SEPARATOR = "\n"
dies_like:  sub (@< @_) { $got = (chomp: ); }, qr/reference as string/, "chomp ref" 
is: (ref: $_), "ARRAY", "chomp ref (no modify)"
$^INPUT_RECORD_SEPARATOR = ")"  # the last char of something like "ARRAY(0x80ff6e4)"
dies_like:  sub (@< @_) { $got = (chomp: ); }, qr/reference as string/, "chomp ref no modify" 
is: (ref: $_), "ARRAY", "chomp ref (no modify)"

$^INPUT_RECORD_SEPARATOR = "\n"

%chomp = %: "One" => "One", "Two\n" => "Two", "" => ""
%chop = %: "One" => "On", "Two\n" => "Two", "" => ""

foreach (keys %chomp)
    my $key = $_
    try {chomp $_}
    if ($^EVAL_ERROR)
        my $err = $^EVAL_ERROR
        $err =~ s/\n$//s
        fail: "\$\@ = \"$err\""
    else
        is: $_, %chomp{?$key}, "chomp hash key"
    


foreach (keys %chop)
    my $key = $_
    try {chop $_}
    if ($^EVAL_ERROR)
        my $err = $^EVAL_ERROR
        $err =~ s/\n$//s
        fail: "\$\@ = \"$err\""
    else
        is: $_, %chop{?$key}, "chop hash key"
    


# chop and chomp can't be lvalues
eval 'chop($x) = 1;'
like: ($^EVAL_ERROR->description: ), qr/Can\'t assign.*chop/
eval 'chomp($x) = 1;'
ok: $^EVAL_ERROR->{?description} =~ m/Can\'t assign.*chom?p/
eval 'chop($x, $y) = (1, 2);'
ok: $^EVAL_ERROR->{?description} =~ m/Can\'t assign.*chop/
eval 'chomp($x, $y) = (1, 2);'
ok: $^EVAL_ERROR->{?description} =~ m/Can\'t assign.*chom?p/

do
    use utf8
    # returns length in code-points, but not in bytes.
    $^INPUT_RECORD_SEPARATOR = "\x{100}"
    $a = "A$^INPUT_RECORD_SEPARATOR"
    $b = chomp $a
    is: $b, 1

    $^INPUT_RECORD_SEPARATOR = "\x{100}\x{101}"
    $a = "A$^INPUT_RECORD_SEPARATOR"
    $b = chomp $a
    is: $b, 2

    # returns length in bytes, not in code-points.
    use utf8;
    $^INPUT_RECORD_SEPARATOR = "\x{100}"
    no utf8;
    $a = "A$^INPUT_RECORD_SEPARATOR"
    is:  (chomp: $a), 2

    use utf8;
    $^INPUT_RECORD_SEPARATOR = "\x{100}\x{101}"
    no utf8;
    $a = "A$^INPUT_RECORD_SEPARATOR"
    is:  (chomp: $a), 4


do
    # [perl #36569] chop fails on decoded string with trailing nul
    my $asc = "perl\0"
    my $utf = "perl".pack: 'U',0 # marked as utf8
    is: (chop: $asc), "\0", "chopping ascii NUL"
    is: (chop: $utf), "\0", "chopping utf8 NUL"
    is: $asc, "perl", "chopped ascii NUL"
    is: $utf, "perl", "chopped utf8 NUL"


do
    # Change 26011: Re: A surprising segfault
    # to make sure only that these obfuscated sentences will not crash.

    map: { (chop: ) }, @:  ('')x68
    ok: 1, "extend sp in pp_chop"

    map: { (chomp: ) }, @:  ('')x68
    ok: 1, "extend sp in pp_chomp"

