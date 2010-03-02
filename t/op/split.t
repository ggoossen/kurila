#!./perl

BEGIN 
    require './test.pl'

plan: tests => 72

our ($FS, $c, @ary, $x, $foo, $res, @list1, @list2, @a, $p, $n)

$FS = ':'

$_ = 'a:b:c'

(@: $a,$b,$c) =  split: $FS,$_

is: (join: ';', (@: $a,$b,$c)), 'a;b;c'

@ary = split: m/:b:/
is: (join: "$_", @ary), 'aa:b:cc'

$_ = "abc\n"
@ary = split: m//
is: (join: ".", @ary), "a.b.c.\n"

$_ = "a:b:c::::"
@ary = split: m/:/
is: (join: ".", @ary), "a.b.c"

$_ = join: ':',(split: ' ',"    a b\tc \t d ")
is: $_, 'a:b:c:d'

$_ = join: ':',(split: m/ */,"foo  bar bie\tdoll")
is: $_ , "f:o:o:b:a:r:b:i:e:\t:d:o:l:l"

$_ = join: ':', (@:  'foo', < (split: m/ /,'a b  c'), 'bar')
is: $_, "foo:a:b::c:bar"

# Can we say how many fields to split to?
$_ = join: ':', (split: ' ','1 2 3 4 5 6', 3)
is: $_, '1:2:3 4 5 6'

# Can we do it as a variable?
$x = 4
$_ = join: ':', (split: ' ','1 2 3 4 5 6', $x)
is: $_, '1:2:3:4 5 6'

# Does the 999 suppress null field chopping?
$_ = join: ':', (split: m/:/,'1:2:3:4:5:6:::', 999)
is: $_ , '1:2:3:4:5:6:::'

# Can we say how many fields to split to when assigning to a list?
(@: $a,$b) =  split: ' ','1 2 3 4 5 6', 2
$_ = join: ':', (@: $a,$b)
is: $_, '1:2 3 4 5 6'

# do subpatterns generate additional fields (without trailing nulls)?
$_ = join: '|', split: m/,|(-)/, "1-10,20,,,"
is: $_, "1|-|10||20"

# do subpatterns generate additional fields (with a limit)?
$_ = join: '|', split: m/,|(-)/, "1-10,20,,,", 10
is: $_, "1|-|10||20||||||"

# is the 'two undefs' bug fixed?
(@: _, $a, _, $b) =  qw(1 2 3 4)
is: "$a|$b", "2|4"

# .. even for locals?
do
    local (@: _, $a, _, $b) =  qw(1 2 3 4)
    is: "$a|$b", "2|4"


# check splitting of null string
$_ = join: '|', (@:  < (split: m/x/,   '',-1), 'Z')
is: $_, "Z"

$_ = join: '|', (@:  < (split: m/x/,   '', 1), 'Z')
is: $_, "Z"

$_ = join: '|', (@:  < (split: m/(p+)/,'',-1), 'Z')
is: $_, "Z"

$_ = join: '|', (@:  < (split: m/.?/,  '',-1), 'Z')
is: $_, "Z"


# Are /^/m patterns scanned?
$_ = join: '|', split: m/^a/m, "a b a\na d a", 20
is: $_, "| b a\n| d a"

# Are /$/m patterns scanned?
$_ = join: '|', split: m/a$/m, "a b a\na d a", 20
is: $_, "a b |\na d |"

# Are /^/m patterns scanned?
$_ = join: '|', split: m/^aa/m, "aa b aa\naa d aa", 20
is: $_, "| b aa\n| d aa"

# Are /$/m patterns scanned?
$_ = join: '|', split: m/aa$/m, "aa b aa\naa d aa", 20
is: $_, "aa b |\naa d |"

# Greedyness:
$_ = "a : b :c: d"
@ary = split: m/\s*:\s*/
is: ($res = (join: ".", @ary)), "a.b.c.d", $res

# use of match result as pattern (!)
is: 'p:q:r:s', (join: ':', (split: 'abc' =~ m/b/, 'p1q1r1s'))

# /^/ treated as /^/m
$_ = join: ':', split: m/^/, "ab\ncd\nef\n"
is: $_, "ab\n:cd\n:ef\n"

# see if @a = @b = split(...) optimization works
@list1 = (@list2 = (split: 'p',"a p b c p"))
ok: (nelems @list1) == nelems @list2 &&
       "$((join: ' ',@list1))" eq "$((join: ' ',@list2))" &&
       (nelems @list1) == 2 &&
       "$((join: ' ',@list1))" eq "a   b c "

# zero-width assertion
$_ = join: ':', split: m/(?=\w)/, "rm b"
is: $_, "r:m :b"

# unicode splittage

use utf8

@ary = split: m/\x{FE}/, "\x{FF}\x{FE}\x{FD}" # bug id 20010105.016
ok: (nelems @ary) == 2 &&
       @ary[0] eq "\x{FF}"   && @ary[1] eq "\x{FD}" &&
       @ary[0] eq "\x{FF}" && @ary[1] eq "\x{FD}"

@ary = split: m/(\x{FE}\x{FE})/, "\x{FF}\x{FF}\x{FE}\x{FE}\x{FD}\x{FD}" # variant of 31
ok: (nelems @ary) == 3 &&
       @ary[0] eq "\x{FF}\x{FF}" &&
       @ary[1] eq "\x{FE}\x{FE}"     &&
       @ary[2] eq "\x{FD}\x{FD}"

do
    my @a = map: { ord }, split: m//, (join: "", (map: { chr }, (@:  (1234, 123, 2345))))
    is: "$((join: ' ',@a))", "1234 123 2345"


do
    my $x = 'A'
    my @a = map: { ord }, split: m/$x/, (join: "", (map: { chr }, (@:  (1234, (ord: $x), 2345))))
    is: "$((join: ' ',@a))", "1234 2345"


do
    # bug id 20000427.003

    use warnings

    my $sushi = "\x{b36c}\x{5a8c}\x{ff5b}\x{5079}\x{505b}"

    my @charlist = split: m//, $sushi
    my $r = ''
    foreach my $ch ( @charlist)
        $r = $r . " " . sprintf: "U+\%04X", ord: $ch
    

    is: $r, " U+B36C U+5A8C U+FF5B U+5079 U+505B"


do
    my $s = "\x20\x40\x{80}\x{100}\x{80}\x40\x20"

    :SKIP do
        if ((ord: 'A') == 193)
            skip: "EBCDIC", 1
        else
            # bug id 20000426.003

            my (@: $a, $b, $c) =  split: m/\x40/, $s
            ok: $a eq "\x20" && $b eq "\x{80}\x{100}\x{80}" && $c eq $a
        
    

    my (@: $a, $b) =  split: m/\x{100}/, $s
    ok: $a eq "\x20\x40\x{80}" && $b eq "\x{80}\x40\x20"

    my (@: $a, $b) =  split: m/\x{80}\x{100}\x{80}/, $s
    ok: $a eq "\x20\x40" && $b eq "\x40\x20"

    :SKIP do
        if ((ord: 'A') == 193)
            skip: "EBCDIC", 1
        else
            my (@: $a, $b) =  split: m/\x40\x{80}/, $s
            ok: $a eq "\x20" && $b eq "\x{100}\x{80}\x40\x20"
        
    

    my (@: $a, $b, $c) =  split: m/[\x40\x{80}]+/, $s
    ok: $a eq "\x20" && $b eq "\x{100}" && $c eq "\x20"


do
    # 20001205.014

    my $a = "ABC\x{263A}"

    my @b = split:  m//, $a 

    is: scalar nelems @b, 4

    ok: (length: @b[3]) == 1 && @b[3] eq "\x{263A}"

    $a =~ s/^A/Z/
    ok: (length: $a) == 4 && $a eq "ZBC\x{263A}"


do
    no utf8
    my @a = split: m/\xFE/, "\x[FF]\x[FE]\x[FD]"

    ok: (nelems @a) == 2 && @a[0] eq "\x[FF]" && @a[1] eq "\x[FD]"


do
    # check that PMf_WHITE is cleared after \s+ is used
    # reported in <20010627113312.RWGY6087.viemta06@localhost>
    my $r
    foreach my $pat ((@:  qr/\s+/, qr/ll/) )
        $r = join: ':', split: $pat, "hello cruel world"
    
    is: $r, "he:o cruel world"



do
    # split /(A)|B/, "1B2" should return (1, undef, 2)
    my @x = split: m/(A)|B/, "1B2"
    ok: @x[0] eq '1' and (not defined @x[1]) and @x[2] eq '2'


do
    # [perl #17064]
    my $warn
    local $^WARN_HOOK = sub (@< @_) { $warn = (join: '', @_); chomp $warn }
    my $char = "\x{10f1ff}"
    my @a = split: m/\r?\n/, "$char\n"
    ok: (nelems @a) == 1 && @a[0] eq $char && !(defined: $warn)


do
    # [perl #18195]
    for my $u ((@: 0, 1))
        for my $a ((@: 0, 1))
            $_ = 'readin,database,readout'
            utf8::encode:  $_ if $u
            m/(.+)/
            my @d = split: m/[,]/,$1
            is: (join: ':', @d), 'readin:database:readout', "[perl #18195]"
        
    


do
    $p="a,b"
    utf8::encode:  $p
    try { @a=(split: m/[, ]+/,$p) }
    is: "$^EVAL_ERROR-$((join: ' ',@a))-", '-a b-', '#20912 - split() to array with /[]+/ and utf8'


do
    # [perl #28938]
    # assigning off the end of the array after a split could leave garbage
    # in the inner elements

    my $x
    @a = split: m/,/, ',,,,,'
    @a[+3]=1
    $x = \@a[2]
    is: ref $x, 'SCALAR', '#28938 - garbage after extend'

do
    # check the special casing of split /\s/ and unicode
    use charnames < qw(:full)
    # below test data is extracted from
    # PropList-5.0.0.txt
    # Date: 2006-06-07, 23:22:52 GMT [MD]
    #
    # Unicode Character Database
    # Copyright (c) 1991-2006 Unicode, Inc.
    # For terms of use, see http://www.unicode.org/terms_of_use.html
    # For documentation, see UCD.html
    my @spaces=@:
        ord: "\t"      # Cc       <control-0009>
        ord: "\n"      # Cc       <control-000A>
        # not PerlSpace # Cc       <control-000B>
        ord: "\f"      # Cc       <control-000C>
        ord: "\r"      # Cc       <control-000D>
        ord: " "       # Zs       SPACE
        
    #diag "Have @{[0+@spaces]} to test\n";
    foreach my $cp ( @spaces)
        my $msg = sprintf: "Space: U+\%04x", $cp
        my $space = chr: $cp
        my $str="A:$space:B"

        my @res=split: m/\s+/,$str
        ok: (nelems @res) == 2 && (join: '-', @res) eq "A:-:B", "$msg - /\\s+/"

        my $s2 = "$space$space:A:$space$space:B"

        my @r2 = split: ' ',$s2
        ok: (nelems @r2) == 2 && (join: '-', @r2) eq ":A:-:B",  "$msg - ' '"

        my @r3 = split: m/\s+/, $s2
        ok: (nelems @r3) == 3 && (join: '-', @r3) eq "-:A:-:B", "$msg - /\\s+/ No.2"
    


do
    my $src = "ABC \0 FOO \0  XYZ"
    my @s = split: " \0 ", $src
    my @r = split: m/ \0 /, $src
    is: (scalar: nelems @s), 3
    is: @s[0], "ABC"
    is: @s[1], "FOO"
    is: @s[2]," XYZ"
    is: (join: ':', @s), (join: ':', @r)

do
    use constant BANG => {};
    @: (split: m/,/, "", (BANG: ));
    (ok: 1);
