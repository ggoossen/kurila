#!./perl

BEGIN 
    require './test.pl'


plan: tests => 90

our ($a, $b, $c)

is: (lc: undef),	   "", "lc(undef) is ''"
is: (lcfirst: undef), "", "lcfirst(undef) is ''"
is: (uc: undef),	   "", "uc(undef) is ''"
is: (ucfirst: undef), "", "ucfirst(undef) is ''"

$a = "HELLO.* world"
$b = "hello.* WORLD"

is: "\Q$a\E."      , "HELLO\\.\\*\\ world.", '\Q\E HELLO.* world'

is: (quotemeta: $a)  , "HELLO\\.\\*\\ world",  'quotemeta'
is: (ucfirst: $a)    , "HELLO\.\* world",      'ucfirst'
is: (lcfirst: $a)    , "hELLO\.\* world",      'lcfirst'
is: (uc: $a)         , "HELLO\.\* WORLD",      'uc'
is: (lc: $a)         , "hello\.\* world",      'lc'

is: "\Q$b\E."      , "hello\\.\\*\\ WORLD.", '\Q\E hello.* WORLD'

is: (quotemeta: $b)  , "hello\\.\\*\\ WORLD",  'quotemeta'
is: (ucfirst: $b)    , "Hello\.\* WORLD",      'ucfirst'
is: (lcfirst: $b)    , "hello\.\* WORLD",      'lcfirst'
is: (uc: $b)         , "HELLO\.\* WORLD",      'uc'
is: (lc: $b)         , "hello\.\* world",      'lc'

use utf8

my ($x100, $x101)
do
    use utf8
    $x100 = "\x{100}"
    $x101 = "\x{101}"


$a = "$($x100)$($x101)Aa"
$b = "$($x101)$($x100)aA"
do
    use utf8

    # \x{100} is LATIN CAPITAL LETTER A WITH MACRON; its bijective lowercase is
    # \x{101}, LATIN SMALL LETTER A WITH MACRON.


    is: "\Q$a\E."      , "\x{100}\x{101}Aa.", '\Q\E \x{100}\x{101}Aa'

    is: (quotemeta: $a)  , "\x{100}\x{101}Aa",  'quotemeta'
    is: (ucfirst: $a)    , "\x{100}\x{101}Aa",  'ucfirst'
    is: (lcfirst: $a)    , "\x{101}\x{101}Aa",  'lcfirst'
    is: (uc: $a)         , "\x{100}\x{100}AA",  'uc'
    is: (lc: $a)         , "\x{101}\x{101}aa",  'lc'

    is: "\Q$b\E."      , "\x{101}\x{100}aA.", '\Q\E \x{101}\x{100}aA'

    is: (quotemeta: $b)  , "\x{101}\x{100}aA",  'quotemeta'
    is: (ucfirst: $b)    , "\x{100}\x{100}aA",  'ucfirst'
    is: (lcfirst: $b)    , "\x{101}\x{100}aA",  'lcfirst'
    is: (uc: $b)         , "\x{100}\x{100}AA",  'uc'
    is: (lc: $b)         , "\x{101}\x{101}aa",  'lc'

    is: (ucfirst: '')    , "",                  'ucfirst empty string'
    is: (lcfirst: '')    , "",                  'lcfirst empty string'

    no utf8;

    local our $TODO ="no utf8 lc"

    is: "\Q$a\E."      , "$($x100)$($x101)Aa.", '\Q\E ${x100}${x101}Aa'

    is: (quotemeta: $a)  , "$($x100)$($x101)Aa",  'quotemeta'
    is: (ucfirst: $a)    , "$($x100)$($x101)Aa",  'ucfirst'
    is: (lcfirst: $a)    , "$($x100)$($x101)Aa",  'lcfirst'
    is: (uc: $a)         , "$($x100)$($x101)AA",  'uc'
    is: (lc: $a)         , "$($x100)$($x101)aa",  'lc'

    is: "\Q$b\E."      , "$($x101)$($x100)aA.", '\Q\E ${x101}${x100}aA'

    is: (quotemeta: $b)  , "$($x101)$($x100)aA",  'quotemeta'
    is: (ucfirst: $b)    , "$($x101)$($x100)aA",  'ucfirst'
    is: (lcfirst: $b)    , "$($x101)$($x100)aA",  'lcfirst'
    is: (uc: $b)         , "$($x101)$($x100)AA",  'uc'
    is: (lc: $b)         , "$($x101)$($x100)aa",  'lc'

# \x{DF} is LATIN SMALL LETTER SHARP S, its uppercase is SS or \x{53}\x{53};
# \x{149} is LATIN SMALL LETTER N PRECEDED BY APOSTROPHE, its uppercase is
# \x{2BC}\x{E4} or MODIFIER LETTER APOSTROPHE and N.

# In EBCDIC \x{DF} is LATIN SMALL LETTER Y WITH DIAERESIS,
# and it's uppercase is \x{178}, LATIN CAPITAL LETTER Y WITH DIAERESIS.

do
    local our $TODO ="multibyte uppercase"
    use utf8;
    is: (uc: "\x{DF}aB\x{149}cD") , "SSAB\x{2BC}NCD"
        "multicharacter uppercase"


# The \x{DF} is its own lowercase, ditto for \x{149}.
# There are no single character -> multiple characters lowercase mappings.

do
    use utf8
    is: (lc: "\x{DF}aB\x{149}cD") , "\x{DF}ab\x{149}cd"
        "multicharacter lowercase"


# titlecase is used for \u / ucfirst.

# \x{587} is ARMENIAN SMALL LIGATURE ECH YIWN and its titlecase is
# \x{535}\x{582} ARMENIAN CAPITAL LETTER ECH + ARMENIAN SMALL LETTER YIWN
# while its lowercase is
# \x{587} itself
# and its uppercase is
# \x{535}\x{552} ARMENIAN CAPITAL LETTER ECH + ARMENIAN CAPITAL LETTER YIWN

use utf8

$a = "\x{587}"

is: (lc: "\x{587}") , "\x{587}",        "ligature lowercase"
do
    local our $TODO ="ligature special case"
    is: (ucfirst: "\x{587}") , "\x{535}\x{582}", "ligature titlecase"
    is: (uc: "\x{587}") , "\x{535}\x{552}", "ligature uppercase"


# mktables had problems where many-to-one case mappings didn't work right.
# The lib/uni/fold.t should give the fourth folding, "casefolding", a good
# workout (one cannot directly get that from Perl).
# \x{01C4} is LATIN CAPITAL LETTER DZ WITH CARON
# \x{01C5} is LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON
# \x{01C6} is LATIN SMALL LETTER DZ WITH CARON
# \x{03A3} is GREEK CAPITAL LETTER SIGMA
# \x{03C2} is GREEK SMALL LETTER FINAL SIGMA
# \x{03C3} is GREEK SMALL LETTER SIGMA

is: (lc: "\x{1C4}") , "\x{1C6}",      "U+01C4 lc is U+01C6"
is: (lc: "\x{1C5}") , "\x{1C6}",      "U+01C5 lc is U+01C6, too"

is: (ucfirst: "\x{3C2}") , "\x{3A3}", "U+03C2 ucfirst is U+03A3"
is: (ucfirst: "\x{3C3}") , "\x{3A3}", "U+03C3 ucfirst is U+03A3, too"

is: (uc: "\x{1C5}") , "\x{1C4}",      "U+01C5 uc is U+01C4"
is: (uc: "\x{1C6}") , "\x{1C4}",      "U+01C6 uc is U+01C4, too"

# #18107: A host of bugs involving [ul]c{,first}. AMS 20021106
$a = "\x{3c3}foo.bar" # \x{3c3} == GREEK SMALL LETTER SIGMA.
$b = "\x{3a3}FOO.BAR" # \x{3a3} == GREEK CAPITAL LETTER SIGMA.

($c = $b) =~ s/(\p{IsWord}+)/$((lc: $1))/g
is: $c , $a, "Using s///e to change case."

($c = $a) =~ s/(\p{IsWord}+)/$((uc: $1))/g
is: $c , $b, "Using s///e to change case."

($c = $b) =~ s/(\p{IsWord}+)/$((lcfirst: $1))/g
is: $c , "\x{3c3}FOO.bAR", "Using s///e to change case."

($c = $a) =~ s/(\p{IsWord}+)/$((ucfirst: $1))/g
is: $c , "\x{3a3}foo.Bar", "Using s///e to change case."

# #18931: perl5.8.0 bug in \U..\E processing
# Test case from Nicholas Clark.
for my $a ((@: 0,1))
    $_ = 'abcdefgh'
    $_ .= chr 256
    chop
    m/(.*)/
    is: (uc: $1), "ABCDEFGH", "[perl #18931]"


do
    foreach ((@: 0, 1))
        local our $TODO = "fix lc"
        $a = "\x{a}"."\x{101}"
        chop $a
        $a =~ s/^(\s*)(\w*)/$("$1".(ucfirst: $2))/
        is: $a, "\x{a}", "[perl #18857]"
    



# [perl #38619] Bug in lc and uc (interaction between UTF-8, substr, and lc/uc)

for ((@: "a\x{100}", "xyz\x{100}"))
    is: (substr: (uc: $_), 0), (uc: $_), "[perl #38619] uc"

for ((@: "A\x{100}", "XYZ\x{100}"))
    is: (substr: (lc: $_), 0), (lc: $_), "[perl #38619] lc"

for ((@: "a\x{100}", "ßyz\x{100}")) # ß to Ss (different length)
    is: (substr: (ucfirst: $_), 0), (ucfirst: $_), "[perl #38619] ucfirst"


# Related to [perl #38619]
# the original report concerns PERL_MAGIC_utf8.
# these cases concern PERL_MAGIC_regex_global.

for ( (map: { $_ }, (@:  "a\x{100}", "abc\x{100}", "\x{100}")))
    chop # get ("a", "abc", "") in utf8
    my $return =  (uc: $_) =~ m/\G(.?)/g
    my $result = $return ?? $1 !! "not"
    my $expect = (@: (uc: $_) =~ m/(.?)/g)[0]
    is: $return, 1,       "[perl #38619]"
    is: $result, $expect, "[perl #38619]"


for ( (map: { $_ }, (@:  "A\x{100}", "ABC\x{100}", "\x{100}")))
    chop # get ("A", "ABC", "") in utf8
    my $return =  (lc: $_) =~ m/\G(.?)/g
    my $result = $return ?? $1 !! "not"
    my $expect = (@: (lc: $_) =~ m/(.?)/g)[0]
    is: $return, 1,       "[perl #38619]"
    is: $result, $expect, "[perl #38619]"


for ((@: 1, 4, 9, 16, 25))
    local our $TODO ="growth"
    is: uc "\x{03B0}" x $_, "\x{3a5}\x{308}\x{301}" x $_
        'uc U+03B0 grows threefold'

    is: lc "\x{0130}" x $_, "i\x{307}" x $_, 'lc U+0130 grows'


# bug #43207
my $temp = "Hello"
for ((@: "$temp"))
    lc $_
    is: $_, "Hello"

