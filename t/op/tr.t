#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 103;

our ($x, $f);

my $Is_EBCDIC = (ord('i') == 0x89 ^&^ ord('J') == 0xd1);

$_ = "abcdefghijklmnopqrstuvwxyz";

tr/a-z/A-Z/;

is($_, "ABCDEFGHIJKLMNOPQRSTUVWXYZ",    'uc');

tr/A-Z/a-z/;

is($_, "abcdefghijklmnopqrstuvwxyz",    'lc');

tr/b-y/B-Y/;
is($_, "aBCDEFGHIJKLMNOPQRSTUVWXYz",    'partial uc');


# In EBCDIC 'I' is \xc9 and 'J' is \0xd1, 'i' is \x89 and 'j' is \x91.
# Yes, discontinuities.  Regardless, the \xca in the below should stay
# untouched (and not became \x8a).
{
    no utf8;
    $_ = "I\x[ca]J";

    tr/I-J/i-j/;

    is($_, "i\x[ca]j",    'EBCDIC discontinuity');
}
#

($x = 12) =~ tr/1/3/;
(my $y = 12) =~ tr/1/3/;
($f = 1.5) =~ tr/1/3/;
(my $g = 1.5) =~ tr/1/3/;
is($x + $y + $f + $g, 71,   'tr cancels IOK and NOK');


# perlbug [ID 20000511.005]
$_ = 'fred';
m/([a-z]{2})/;
$1 =~ tr/A-Z//;
s/^(\s*)f/$1F/;
is($_, 'Fred',  'harmless if explicitly not updating');


# A variant of the above, added in 5.7.2
$_ = 'fred';
m/([a-z]{2})/;
eval '$1 =~ tr/A-Z/A-Z/;';
s/^(\s*)f/$1F/;
is($_, 'Fred',  'harmless if implicitly not updating');
is($@, '',      '    no error');


use utf8;

# check tr handles UTF8 correctly
($x = "\x{100}A\x{100}") =~ tr/a/b/;
is($x, "\x{100}A\x{100}",  'handles UTF8');
is(length $x, 3);

$x =~ tr/A/B/;
is(length $x, 3);
is($x, "\x{100}B\x{100}");

{
    my $l = chr(300); my $r = chr(400);
    $x = "\x{c8}\x{12c}\x{190}";
    $x =~ tr/\x{12c}/\x{190}/;
    is($x, "\x{c8}\x{190}\x{190}",
                        'changing UTF8 chars in a UTF8 string, same length');
    is(length $x, 3);

    $x = "\x{c8}\x{12c}\x{190}";
    $x =~ tr/\x{12c}/\x{be8}/;
    is($x, "\x{c8}\x{be8}\x{190}",    '    more bytes');
    is(length $x, 3);

    $x = "\x{64}\x{7d}\x{3c}";
    $x =~ tr/\x{64}/\x{190}/;
    is($x, "\x{190}\x{7d}\x{3c}",      'Putting UT8 chars into a non-UTF8 string');
    is(length $x, 3);

    $x = "\x{190}\x{7d}\x{3c}";
    $x =~ tr/\x{190}/\x{64}/;
    is($x, "\x{64}\x{7d}\x{3c}",      'Removing UTF8 chars from UTF8 string');
    is(length $x, 3);

    $x = "\x{190}abc\x{190}";
    $y = $x =~ tr/\x{190}/\x{190}/;
    is($y, 2,               'Counting UTF8 chars in UTF8 string');

    $x = "\x{3c}\x{190}\x{7d}\x{3c}\x{190}";
    $y = $x =~ tr/\x{3c}/\x{3c}/;
    is($y, 2,               '         non-UTF8 chars in UTF8 string');

    # 17 - counting UTF8 chars in non-UTF8 string
    $x = "\x{c8}\x{7d}\x{3c}";
    $y = $x =~ tr/\x{190}/\x{190}/;
    is($y, 0,               '         UTF8 chars in non-UTFs string');
}

$_ = "abcdefghijklmnopqrstuvwxyz";
eval_dies_like( 'tr/a-z-9/ /',
                qr/^Ambiguous range in transliteration operator/,  'tr/a-z-9//');

# 19-21: Make sure leading and trailing hyphens still work
$_ = "car-rot9";
tr/-a-m/./;
is($_, '..r.rot9',  'hyphens, leading');

$_ = "car-rot9";
tr/a-m-/./;
is($_, '..r.rot9',  '   trailing');

$_ = "car-rot9";
tr/-a-m-/./;
is($_, '..r.rot9',  '   both');

$_ = "abcdefghijklmnop";
tr/ae-hn/./;
is($_, '.bcd....ijklm.op');

$_ = "abcdefghijklmnop";
tr/a-cf-kn-p/./;
is($_, '...de......lm...');

$_ = "abcdefghijklmnop";
tr/a-ceg-ikm-o/./;
is($_, '...d.f...j.l...p');


# 20000705 MJD
eval_dies_like( "tr/m-d/ /",
                qr/^Invalid range "m-d" in transliteration operator/,
                'reversed range check');

'abcdef' =~ m/(bcd)/;
is(eval '$1 =~ tr/abcd//', 3,  'explicit read-only count');
is($@, '',                      '    no error');

'abcdef' =~ m/(bcd)/;
is(eval '$1 =~ tr/abcd/abcd/', 3,  'implicit read-only count');
is($@, '',                      '    no error');

is(eval '"123" =~ tr/12//', 2,     'LHS of non-updating tr');

eval_dies_like( '"123" =~ tr/1/2/',
                qr|^Can't modify constant item in transliteration \(tr///\)|,
                'LHS bad on updating tr');


# v300 (0x12c) is UTF-8-encoded as 196 172 (0xc4 0xac)
# v400 (0x190) is UTF-8-encoded as 198 144 (0xc6 0x90)

# Transliterate a byte to a byte, all four ways.
{
    use bytes;
    ($a = "a\x[c4]b\x[c4]") =~ tr/\x[c4]/\x[c5]/;
    is($a, "a\x[c5]b\x[c5]",    'byte2byte transliteration');

    is((($a = "a\x[c4]b\x[c4]") =~ tr/\x[c4]/\x[c5]/), 2,
       'transliterate and count');
}

is((($a = "a\x{12c}b\x{12c}") =~ tr/\x{12c}/\x{12d}/), 2);

($a = "a\x{c4}b\x{c4}") =~ tr/\x{c4}/\x{12d}/c;
is($a, "\x{12d}\x{c4}\x{12d}\x{c4}",    'translit w/complement');

($a = "a\x{c4}b\x{c4}") =~ tr/\x{c4}//d;
is($a, "ab",            'translit w/deletion');

($a = "\x{c4}\x{c4}\x{ac}\x{12c}\x{12c}\x{c4}\x{ac}") =~ tr/\x{c4}/\x{c5}/s;
is($a, "\x{c5}\x{ac}\x{12c}\x{12c}\x{c5}\x{ac}",    'translit w/squeeze');

($a = "\x{c4}\x{ac}\x{12c}\x{12c}\x{c4}\x{ac}\x{ac}") =~ tr/\x{12c}/\x{12d}/s;
is($a, "\x{c4}\x{ac}\x{12d}\x{c4}\x{ac}\x{ac}");


# Tricky cases (When Simon Cozens Attacks)
($a = "\x{c4}\x{ac}\x{c8}") =~ tr/\x{12c}/a/;
is(sprintf("%vd", $a), '196.172.200');

($a = "\x{c4}\x{ac}\x{c8}") =~ tr/\x{12c}/\x{12c}/;
is(sprintf("%vd", $a), '196.172.200');

($a = "\x{c4}\x{ac}\x{c8}") =~ tr/\x{12c}//d;
is(sprintf("%vd", $a), '196.172.200');


# UTF8 range tests from Inaba Hiroto

# Not working in EBCDIC as of 12674.
($a = "\x{12c}\x{c4}\x{ac}\x{12e}\x{c5}\x{ac}") =~ tr/\x{12c}-\x{130}/\x{c0}-\x{c4}/;
is($a, "\x{c0}\x{c4}\x{ac}\x{c2}\x{c5}\x{ac}",    'UTF range');

($a = "\x{12c}\x{c4}\x{ac}\x{12e}\x{c5}\x{ac}") =~ tr/\x{c4}-\x{c8}/\x{12c}-\x{130}/;
is($a, "\x{12c}\x{12c}\x{ac}\x{12e}\x{12d}\x{ac}");


# UTF8 range tests from Karsten Sperling (patch #9008 required)

($a = "\x{0100}") =~ tr/\x00-\x{100}/X/;
is($a, "X");

($a = "\x{0100}") =~ tr/\x{0000}-\x{00ff}/X/c;
is($a, "X");

($a = "\x{0100}") =~ tr/\x{0000}-\x{00ff}\x{0101}/X/c;
is($a, "X");
 
($a = "\x{100}") =~ tr/\x{0000}-\x{00ff}\x{0101}/X/c;
is($a, "X");


# UTF8 range tests from Inaba Hiroto

($a = "\x{200}") =~ tr/\x00-\x{100}/X/c;
is($a, "X");

($a = "\x{200}") =~ tr/\x00-\x{100}/X/cs;
is($a, "X");


# Tricky on EBCDIC: while [a-z] [A-Z] must not match the gap characters,
# (i-j, r-s, I-J, R-S), [\x89-\x91] [\xc9-\xd1] has to match them,
# from Karsten Sperling.

{
use bytes;
$c = ($a = "\x[89]\x[8a]\x[8b]\x[8c]\x[8d]\x[8f]\x[90]\x[91]") =~ tr/\x[89]-\x[91]/X/;
is($c, 8);
is($a, "XXXXXXXX");

$c = ($a = "\x[c9]\x[ca]\x[cb]\x[cc]\x[cd]\x[cf]\x[d0]\x[d1]") =~ tr/\x[c9]-\x[d1]/X/;
is($c, 8);
is($a, "XXXXXXXX");
}

SKIP: {
    skip "not EBCDIC", 4 unless $Is_EBCDIC;

    $c = ($a = "\x[89]\x[8a]\x[8b]\x[8c]\x[8d]\x[8f]\x[90]\x[91]") =~ tr/i-j/X/;
    is($c, 2);
    is($a, "X\x[8a]\x[8b]\x[8c]\x[8d]\x[8f]\x[90]X");
   
    $c = ($a = "\x[c9]\x[ca]\x[cb]\x[cc]\x[cd]\x[cf]\x[d0]\x[d1]") =~ tr/I-J/X/;
    is($c, 2);
    is($a, "X\x[ca]\x[cb]\x[cc]\x[cd]\x[cf]\x[d0]X");
}

my $x = "\x{100}";
use bytes;
{
    local $TODO = "byte range";
    ($a = $x) =~ tr/\x[00]-\x[ff]/X/c;
    is(ord($a), ord("X"), "byte tr///");

    ($a = $x) =~ tr/\x[00]-\x[ff]/X/cs;
    is(ord($a), ord("X"), "byte tr///");
}

use utf8;
($a = "\x{100}\x{100}") =~ tr/\x{101}-\x{200}//c;
is($a, "\x{100}\x{100}");

($a = "\x{100}\x{100}") =~ tr/\x{101}-\x{200}//cs;
is($a, "\x{100}");

$a = "\x{fe}\x{ff}"; $a =~ tr/\x{fe}\x{ff}/\x{1ff}\x{1fe}/;
is($a, "\x{1ff}\x{1fe}");


# From David Dyck
($a = "R0_001") =~ tr/R_//d;
is(hex($a), 1);

# From Inaba Hiroto
@a = (1,2); map { y/1/./ for $_ } @a;
is("@a", ". 2");

@a = (1,2); map { y/1/./ for $_.'' } @a;
is("@a", "1 2");


# Additional test for Inaba Hiroto patch (robin@kitsite.com)
($a = "\x{100}\x{102}\x{101}") =~ tr/\x00-\x{ff}/XYZ/c;
is($a, "XZY");


# Used to fail with "Modification of a read-only value attempted"
%a = (N=>1);
foreach (keys %a) {
  eval 'tr/N/n/';
  is($_, 'n',   'pp_trans needs to unshare shared hash keys');
  is($@, '',    '   no error');
}


$x = eval '"1213" =~ tr/1/1/';
is($x, 2,   'implicit count on constant');
is($@, '',  '   no error');


my @foo = ();
eval '$foo[-1] =~ tr/N/N/';
is( $@, '',         'implicit count outside array bounds, index negative' );
is( scalar @foo, 0, "    doesn't extend the array");

eval '$foo[1] =~ tr/N/N/';
is( $@, '',         'implicit count outside array bounds, index positive' );
is( scalar @foo, 0, "    doesn't extend the array");


my %foo = ();
eval '$foo{bar} =~ tr/N/N/';
is( $@, '',         'implicit count outside hash bounds' );
is( scalar keys %foo, 0,   "    doesn't extend the hash");

$x = \"foo";
dies_like( sub { $x =~ tr/A/A/; }, qr/Tried to use reference as string/ );
is( ref $x, 'SCALAR', "    doesn't stringify its argument" );

# rt.perl.org 36622.  Perl didn't like a y/// at end of file.  No trailing
# newline allowed.
fresh_perl_is(q[$_ = "foo"; y/A-Z/a-z/], '');


{ # [perl #38293] chr(65535) should be allowed in regexes
no warnings 'utf8'; # to allow non-characters

$s = "\x{d800}\x{ffff}";
$s =~ tr/\0/A/;
is($s, "\x{d800}\x{ffff}", "do_trans_simple");

$s = "\x{d800}\x{ffff}";
$i = $s =~ tr/\0//;
is($i, 0, "do_trans_count");

$s = "\x{d800}\x{ffff}";
$s =~ tr/\0/A/s;
is($s, "\x{d800}\x{ffff}", "do_trans_complex, SQUASH");

$s = "\x{d800}\x{ffff}";
$s =~ tr/\0/A/c;
is($s, "AA", "do_trans_complex, COMPLEMENT");

$s = "A\x{ffff}B";
$s =~ tr/\x{ffff}/\x{1ffff}/;
is($s, "A\x{1ffff}B", "utf8, SEARCHLIST");

$s = "\x{fffd}\x{fffe}\x{ffff}";
$s =~ tr/\x{fffd}-\x{ffff}/ABC/;
is($s, "ABC", "utf8, SEARCHLIST range");

$s = "ABC";
$s =~ tr/ABC/\x{ffff}/;
is($s, "\x{ffff}"x3, "utf8, REPLACEMENTLIST");

$s = "ABC";
$s =~ tr/ABC/\x{fffd}-\x{ffff}/;
is($s, "\x{fffd}\x{fffe}\x{ffff}", "utf8, REPLACEMENTLIST range");

$s = "A\x{ffff}B\x{100}\0\x{fffe}\x{ffff}";
$i = $s =~ tr/\x{ffff}//;
is($i, 2, "utf8, count");

$s = "A\x{ffff}\x{ffff}C";
$s =~ tr/\x{ffff}/\x{100}/s;
is($s, "A\x{100}C", "utf8, SQUASH");

$s = "A\x{ffff}\x{ffff}\x{fffe}\x{fffe}\x{fffe}C";
$s =~ tr/\x{fffe}\x{ffff}//s;
is($s, "A\x{ffff}\x{fffe}C", "utf8, SQUASH");

$s = "xAABBBy";
$s =~ tr/AB/\x{ffff}/s;
is($s, "x\x{ffff}y", "utf8, SQUASH");

$s = "xAABBBy";
$s =~ tr/AB/\x{fffe}\x{ffff}/s;
is($s, "x\x{fffe}\x{ffff}y", "utf8, SQUASH");

$s = "A\x{ffff}B\x{fffe}C";
$s =~ tr/\x{fffe}\x{ffff}/x/c;
is($s, "x\x{ffff}x\x{fffe}x", "utf8, COMPLEMENT");

$s = "A\x{10000}B\x{2abcd}C";
$s =~ tr/\0-\x{ffff}/x/c;
is($s, "AxBxC", "utf8, COMPLEMENT range");

$s = "A\x{fffe}B\x{ffff}C";
$s =~ tr/\x{fffe}\x{ffff}/x/d;
is($s, "AxBC", "utf8, DELETE");

} # non-characters end

{ # related to [perl #27940]
    my $c;

    ($c = "\x20\c@\x30\cA\x40\cZ\x50\c_\x60") =~ tr/\c@-\c_//d;
    is($c, "\x20\x30\x40\x50\x60", "tr/\\c\@-\\c_//d");

    ($c = "\x20\x00\x30\x01\x40\x1A\x50\x1F\x60") =~ tr/\x00-\x1f//d;
    is($c, "\x20\x30\x40\x50\x60", "tr/\\x00-\\x1f//d");
}

