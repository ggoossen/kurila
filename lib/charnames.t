#!./perl

my @WARN

BEGIN 
    $^WARN_HOOK = sub (@< @_) { (push: @WARN, @_[0]->{?description}) }


BEGIN 
    require "./test.pl"

require File::Spec

$^OUTPUT_AUTOFLUSH = 1

plan: tests => 76

use utf8

use charnames ':full'

is: "Here\N{EXCLAMATION MARK}?", "Here!?"

our ($res, $encoded_be, $encoded_alpha, $encoded_bet, $encoded_deseng)

# If octal representation of unicode char is \0xyzt, then the utf8 is \3xy\2zt
do # as on ASCII or UTF-8 machines
    $encoded_be = "\320\261"
    $encoded_alpha = "\316\261"
    $encoded_bet = "\327\221"
    $encoded_deseng = "\360\220\221\215"


sub to_bytes
    unpack: "U0a*", shift


do
    use charnames ':full'

    ok: (to_bytes: "\N{CYRILLIC SMALL LETTER BE}") eq $encoded_be

    use charnames < qw(cyrillic greek :short);

    ok: to_bytes: "\N{be},\N{alpha},\N{hebrew:bet}"
           eq "$encoded_be,$encoded_alpha,$encoded_bet"


do
    use charnames ':full'
    ok: "\x{263a}" eq "\N{WHITE SMILING FACE}"
    ok: (length: "\x{263a}") == 1
    ok: (length: "\N{WHITE SMILING FACE}") == 1
    ok: (sprintf: "\%vx", "\N{WHITE SMILING FACE}") eq "263a"
    ok: (sprintf: "\%vx", "\x{FF}\N{WHITE SMILING FACE}") eq "ff.263a"
    ok: (sprintf: "\%vx", "\x{ff}\N{WHITE SMILING FACE}") eq "ff.263a"


do
    use charnames < qw(:full)
    use utf8

    my $x = "\x{221b}"
    my $named = "\N{CUBE ROOT}"

    ok: (ord: $x) == ord: $named


do
    use charnames < qw(:full)
    use utf8
    ok: "\x{100}\N{CENT SIGN}" eq "\x{100}"."\N{CENT SIGN}"


do
    use charnames ':full'

    ok: (to_bytes: "\N{DESERET SMALL LETTER ENG}") eq $encoded_deseng


do
    # 20001114.001

    no utf8 # naked Latin-1

    use charnames ':full'
    my $text = "\N{LATIN CAPITAL LETTER A WITH DIAERESIS}"
    ok: $text eq "\x{c4}" && (utf8::ord: $text) == 0xc4


do
    ok: (charnames::viacode: 0x1234) eq "ETHIOPIC SYLLABLE SEE"

    # Unused Hebrew.
    ok: not defined charnames::viacode: 0x0590


do
    ok: (sprintf: "\%04X", (charnames::vianame: "GOTHIC LETTER AHSA")) eq "10330"

    ok: not defined charnames::vianame: "NONE SUCH"


do
    # check that caching at least hasn't broken anything

    ok: (charnames::viacode: 0x1234) eq "ETHIOPIC SYLLABLE SEE"

    ok: (sprintf: "\%04X", (charnames::vianame: "GOTHIC LETTER AHSA")) eq "10330"



ok: "\N{CHARACTER TABULATION}" eq "\t"

ok: "\N{ESCAPE}" eq "\e"

ok: "\N{NULL}" eq "\c@"

if ($^OS_NAME eq 'MacOS')
    ok: "\N{CARRIAGE RETURN (CR)}" eq "\n"
    ok: "\N{CARRIAGE RETURN}" eq "\n"
    ok: "\N{CR}" eq "\n"
else
    ok: "\N{LINE FEED (LF)}" eq "\n"
    ok: "\N{LINE FEED}" eq "\n"
    ok: "\N{LF}" eq "\n"


my $nel = (ord: "A") == 193 ?? qr/^(?:\x15|\x25)$/ !! qr/^\x85$/

ok: "\N{NEXT LINE (NEL)}" =~ $nel
ok: "\N{NEXT LINE}" =~ $nel
ok: "\N{NEL}" =~ $nel
ok: "\N{BYTE ORDER MARK}" eq chr: 0xFEFF
ok: "\N{BOM}" eq chr: 0xFEFF

do
    use warnings 'deprecated'

    ok: "\N{HORIZONTAL TABULATION}" eq "\t"

    ok: grep: { m/"HORIZONTAL TABULATION" is deprecated/ }, @WARN

    no warnings 'deprecated';

    ok: "\N{VERTICAL TABULATION}" eq "\013"

    ok: not grep: { m/"VERTICAL TABULATION" is deprecated/ }, @WARN


ok: (charnames::viacode: 0xFEFF) eq "ZERO WIDTH NO-BREAK SPACE"

do
    use warnings
    ok: (ord: "\N{BOM}") == 0xFEFF


ok: (ord: "\N{ZWNJ}") == 0x200C
ok: (ord: "\N{ZWJ}") == 0x200D
ok: "\N{U+263A}" eq "\N{WHITE SMILING FACE}"

do
    ok: 0x3093 == charnames::vianame: "HIRAGANA LETTER N"
    ok: 0x0397 == charnames::vianame: "GREEK CAPITAL LETTER ETA"


ok: not defined charnames::viacode: 0x110000
ok: not grep: { m/you asked for U+110000/ }, @WARN


# ---- Alias extensions

my $alifile = File::Spec->catfile: File::Spec->updir, < qw(lib unicore xyzzy_alias.pl)

my @prgs
do 
    local $^INPUT_RECORD_SEPARATOR = undef
    @prgs = split: "\n########\n", ~< $^DATA

for ( @prgs)
    my (@: $code, $exp, ...) = @: ( <(split: m/\nEXPECT\n/)), '$'
    my (@: $prog, $fil, ...) = @: ( <(split: m/\nFILE\n/, $code)), ""
    $prog = "use utf8; " . $prog
    my $tmpfile = (tempfile: )
    open: my $tmp, ">", "$tmpfile" or die: "Could not open $tmpfile: $^OS_ERROR"
    print: $tmp, $prog, "\n"
    close $tmp or die: "Could not close $tmpfile: $^OS_ERROR"
    if ($fil)
        $fil .= "\n"
        open: my $ali, ">", "$alifile" or die: "Could not open $alifile: $^OS_ERROR"
        print: $ali, $fil
        close $ali or die: "Could not close $alifile: $^OS_ERROR"
    
    my $res = runperl:  progfile => $tmpfile
                        stderr => 1 
    my $status = $^CHILD_ERROR
    $res =~ s/[\r\n]+$//
    $res =~ s/tmp\d+/-/g			# fake $prog from STDIN
    $res =~ s/\n%[A-Z]+-[SIWEF]-.*$//		# clip off DCL status msg
        if $^OS_NAME eq "VMS"
    $exp =~ s/[\r\n]+$//
    if ($^OS_NAME eq "MacOS")
        $exp =~ s{(\./)?abc\.pm}{:abc.pm}g
        $exp =~ s{./abc}        {:abc}g
    
    my $pfx = ($res =~ s/^PREFIX\n//)
    my $rexp = qr{^$exp}
    if ($res =~ s/^SKIPPED\n//)
        print: $^STDOUT, "$res\n"
    elsif (($pfx and $res !~ m/^\Q$exp/) or
        (!$pfx and $res !~ $rexp))
        print: $^STDERR
               "PROG:\n$prog\n"
               "FILE:\n$fil"
               "EXPECTED:\n$exp\n"
               "GOT:\n$res\n"
        print: $^STDOUT, "not "
    
    ok: 1
    $fil or next
    1 while unlink: $alifile


# [perl #30409] charnames.pm clobbers default variable
$_ = 'foobar'
eval "use charnames ':full';"; die: if $^EVAL_ERROR
ok: $_ eq 'foobar'

# Unicode slowdown noted by Phil Pennock, traced to a bug fix in index
# SADAHIRO Tomoyuki's suggestion is to ensure that the UTF-8ness of both
# arguments are indentical before calling index.
# To do this can take advantage of the fact that unicore/Name.pl is 7 bit
# (or at least should be). So assert that that it's true here.

my $names = evalfile "unicore/Name.pl"
ok: defined $names
do # as on ASCII or UTF-8 machines
    my $non_ascii = $names =~ s/[^\0-\177]//g
    ok: not $non_ascii


# Verify that charnames propagate to eval("")
my $evaltry = eval q[ "Eval: \N{LEFT-POINTING DOUBLE ANGLE QUOTATION MARK}" ]
ok: not $^EVAL_ERROR
ok: $evaltry eq "Eval: \N{LEFT-POINTING DOUBLE ANGLE QUOTATION MARK}"

# Verify that db includes the normative NameAliases.txt names
is: "\N{BYZANTINE MUSICAL SYMBOL FTHORA SKLIRON CHROMA VASIS}", "\N{U+1D0C5}"


__END__
# unsupported pragma
use charnames ":scoobydoo";
"Here: \N{e_ACUTE}!\n";
EXPECT
unsupported special ':scoobydoo' in charnames at
########
# wrong type of alias (missing colon)
use charnames "alias";
"Here: \N{e_ACUTE}!\n";
EXPECT
Unknown charname 'e_ACUTE' at
########
# alias without an argument
use charnames ":alias";
"Here: \N{e_ACUTE}!\n";
EXPECT
:alias needs an argument in charnames at
########
# reversed sequence
use charnames ":alias" => ":full";
"Here: \N{e_ACUTE}!\n";
EXPECT
:alias cannot use existing pragma :full \(reversed order\?\) at
########
# alias with hashref but no :full
use charnames ":alias" => \(%: e_ACUTE => "LATIN SMALL LETTER E WITH ACUTE" );
"Here: \N{e_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN SMALL LETTER E WITH ACUTE' at
########
# alias with hashref but with :short
use charnames ":short", ":alias" => \%: e_ACUTE => "LATIN SMALL LETTER E WITH ACUTE"
"Here: \N{e_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN SMALL LETTER E WITH ACUTE' at
########
# alias with hashref to :full OK
use charnames ":full", ":alias" => \%: e_ACUTE => "LATIN SMALL LETTER E WITH ACUTE"
"Here: \N{e_ACUTE}!\n";
EXPECT
$
########
# alias with hashref to :short but using :full
use charnames ":full", ":alias" => \%: e_ACUTE => "LATIN:e WITH ACUTE"
"Here: \N{e_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN:e WITH ACUTE' at
########
# alias with hashref to :short OK
use charnames ":short", ":alias" => \%: e_ACUTE => "LATIN:e WITH ACUTE"
"Here: \N{e_ACUTE}!\n";
EXPECT
$
########
# alias with bad hashref
use charnames ":short", ":alias" => "e_ACUTE";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
unicore/e_ACUTE_alias.pl cannot be used as alias file for charnames at
########
# alias with arrayref
use charnames ":short", ":alias" => \@: e_ACUTE => "LATIN:e WITH ACUTE" ;
"Here: \N{e_ACUTE}!\n";
EXPECT
Only HASH reference supported as argument to :alias at
########
# alias with bad hashref
use charnames ":short", ":alias" => \%: e_ACUTE => "LATIN:e WITH ACUTE", "a_ACUTE"
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Use of uninitialized value
########
# alias with hashref two aliases
use charnames ":short", ":alias" => \%:
    e_ACUTE => "LATIN:e WITH ACUTE"
    a_ACUTE => ""

"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Unknown charname '' at
########
# alias with hashref two aliases
use charnames ":short", ":alias" => \%:
    e_ACUTE => "LATIN:e WITH ACUTE"
    a_ACUTE => "LATIN:a WITH ACUTE"

"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
$
########
# alias with hashref using mixed aliasses
use charnames ":short", ":alias" => \%:
    e_ACUTE => "LATIN:e WITH ACUTE"
    a_ACUTE => "LATIN SMALL LETTER A WITH ACUT"

"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN SMALL LETTER A WITH ACUT' at
########
# alias with hashref using mixed aliasses
use charnames ":short", ":alias" => \%:
    e_ACUTE => "LATIN:e WITH ACUTE"
    a_ACUTE => "LATIN SMALL LETTER A WITH ACUTE"

"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN SMALL LETTER A WITH ACUTE' at
########
# alias with hashref using mixed aliasses
use charnames ":full", ":alias" => \%:
    e_ACUTE => "LATIN:e WITH ACUTE"
    a_ACUTE => "LATIN SMALL LETTER A WITH ACUTE"

"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Unknown charname 'LATIN:e WITH ACUTE' at
########
# alias with nonexisting file
use charnames ":full", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
unicore/xyzzy_alias.pl cannot be used as alias file for charnames at
########
# alias with bad file name
use charnames ":full", ":alias" => "xy 7-";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
Charnames alias files can only have identifier characters at
########
# alias with non_absolute (existing) file name (which it should /not/ use)
use charnames ":full", ":alias" => "perl";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
EXPECT
unicore/perl_alias.pl cannot be used as alias file for charnames at
########
# alias with bad file
use charnames ":full", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
0;
EXPECT
unicore/xyzzy_alias.pl did not return a \(valid\) list of alias pairs at
########
# alias with file with empty list
use charnames ":full", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
();
EXPECT
Unknown charname 'e_ACUTE' at
########
# alias with file OK but file has :short aliasses
use charnames ":full", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
(   e_ACUTE => "LATIN:e WITH ACUTE",
    a_ACUTE => "LATIN:a WITH ACUTE",
    );
EXPECT
Unknown charname 'LATIN:e WITH ACUTE' at
########
# alias with :short and file OK
use charnames ":short", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
(   e_ACUTE => "LATIN:e WITH ACUTE",
    a_ACUTE => "LATIN:a WITH ACUTE",
    );
EXPECT
$
########
# alias with :short and file OK has :long aliasses
use charnames ":short", ":alias" => "xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
(   e_ACUTE => "LATIN SMALL LETTER E WITH ACUTE",
    a_ACUTE => "LATIN SMALL LETTER A WITH ACUTE",
    );
EXPECT
Unknown charname 'LATIN SMALL LETTER E WITH ACUTE' at
########
# alias with file implicit :full but file has :short aliasses
use charnames ":alias" => ":xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
(   e_ACUTE => "LATIN:e WITH ACUTE",
    a_ACUTE => "LATIN:a WITH ACUTE",
    );
EXPECT
Unknown charname 'LATIN:e WITH ACUTE' at
########
# alias with file implicit :full and file has :long aliasses
use charnames ":alias" => ":xyzzy";
"Here: \N{e_ACUTE}\N{a_ACUTE}!\n";
FILE
#!perl
(   e_ACUTE => "LATIN SMALL LETTER E WITH ACUTE",
    a_ACUTE => "LATIN SMALL LETTER A WITH ACUTE",
    );
EXPECT
$
