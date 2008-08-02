#!./perl

BEGIN {
    require Config;
    if ((%Config::Config{'extensions'} !~ m/\bB\b/) ){
        print "1..0 # Skip -- Perl configured without B module\n";
        exit 0;
    }
}

use warnings;
use strict;
use feature ":5.10";
use Test::More tests => 60;

use B::Deparse;
my $deparse = B::Deparse->new();
ok($deparse);

# Tell B::Deparse about our ambient pragmas
{ my ($hint_bits, $warning_bits, $hinthash);
 BEGIN { ($hint_bits, $warning_bits, $hinthash) = ($^H, $^WARNING_BITS, \%^H); }
 $deparse->ambient_pragmas (
     hint_bits    => $hint_bits,
     warning_bits => $warning_bits,
     '%^H'	  => $hinthash,
 );
}

$/ = "\n####\n";
while ( ~< *DATA) {
    chomp;
    s/#\s*(.*)$//mg;
    my ($num, $testname) = $1 =~ m/(\d+)\s*(.*)/;
    my ($input, $expected);
    if (m/(.*)\n>>>>\n(.*)/s) {
	($input, $expected) = ($1, $2);
    }
    else {
	($input, $expected) = ($_, $_);
    }

    my $coderef = eval "sub \{$input\}";

    if ($@ and $@->{description}) {
	diag("$num deparsed: {$@->message}");
        diag("input: '$input'");
	ok(0, $testname);
    }
    else {
	my $deparsed = $deparse->coderef2text( $coderef );
	my $regex = $expected;
	$regex =~ s/(\S+)/\Q$1/g;
	$regex =~ s/\s+/ \\s+ /g;
	$regex = '^ \{ \s* ' . $regex . ' \s* \} $';
        like($deparsed, qr/$regex/x, $testname);
    }
}

use constant 'c', 'stuff';
is((eval "sub ".$deparse->coderef2text(\&c))->(), 'stuff');

my $a = 0;
is("\{\n    (-1) ** \$a;\n\}", $deparse->coderef2text(sub{(-1) ** $a }));

use constant cr => \@('hello');
my $string = "sub " . $deparse->coderef2text(\&cr);
my $subref = eval $string;
die "Failed eval '$string': {$@->message}" if $@;
my $val = $subref->() or diag $string;
is(ref($val), 'ARRAY');
is($val->[0], 'hello');

my $Is_VMS = $^O eq 'VMS';
my $Is_MacOS = $^O eq 'MacOS';

my $path = join " ", map { qq["-I$_"] } < @INC;
$path .= " -MMac::err=unix" if $Is_MacOS;
my $redir = $Is_MacOS ? "" : "2>&1";

$a = `$^X $path "-MO=Deparse" -anlwi.bak -e 1 $redir`;
$a =~ s/-e syntax OK\n//g;
$a =~ s/.*possible typo.*\n//;	   # Remove warning line
$a =~ s{\\340\\242}{\\s} if (ord("\\") == 224); # EBCDIC, cp 1047 or 037
$a =~ s{\\274\\242}{\\s} if (ord("\\") == 188); # $^O eq 'posix-bc'
$b = <<'EOF';
BEGIN { $^I = ".bak"; }
BEGIN { $^W = 1; }
BEGIN { $/ = "\n"; $\ = "\n"; }
LINE: while (defined($_ = ~< *ARGV)) {
    chomp $_;
    our(@main::F) = split(' ', $_, 0);
    '???';
}
EOF
$b =~ s/(LINE:)/sub BEGIN {
    'MacPerl'->bootstrap;
    'OSA'->bootstrap;
    'XL'->bootstrap;
}
$1/ if $Is_MacOS;
is($a, $b);

#Re: perlbug #35857, patch #24505
#handle warnings::register-ed packages properly.
package B::Deparse::Wrapper;
use strict;
use warnings;
use warnings::register;
sub getcode {
   my $deparser = B::Deparse->new();
   return $deparser->coderef2text(shift);
}

package main;
use strict;
use warnings;
sub test {
   my $val = shift;
   my $res = B::Deparse::Wrapper::getcode($val);
   like( $res, qr/use warnings/);
}
my ($q,$p);
my $x=sub { @( ++$q,++$p ) };
test($x);
eval <<EOFCODE and test($x);
   package bar;
   use strict;
   use warnings;
   use warnings::register;
   package main;
   1
EOFCODE

__DATA__
# 2
1;
####
# 3
{
    no warnings;
    '???';
    2;
}
####
# 4
my $test;
++$test and $test /= 2;
>>>>
my $test;
$test /= 2 if ++$test;
####
# 5
-((1, 2) x 2);
####
# 6
1;
####
# 7
{
    my $test = sub : method {
	my $x;
    }
    ;
}
####
# 8
{
    my $test = sub : locked method {
	my $x;
    }
    ;
}
####
# 10
my $x;
print $main::x;
####
# 11
my @x;
print @main::x[1];
####
# 12
my %x;
%x{warn()};
####
my($x, $y) = < @('xx', 'yy');
####
my @x = @( 1..10 );
####
# 13
my $foo;
$_ .= ~<(*ARGV) . ~<($foo);
####
# 14
use utf8;
my $foo = "Ab\x{100}\200\x{200}\377Cd\000Ef\x{1000}\cA\x{2000}\cZ";
>>>>
my $foo = "Ab\304\200\200\310\200\377Cd\000Ef\341\200\200\cA\342\200\200\cZ";
####
# 15
s/x/{ 'y' }/;
####
# 16 - various lypes of loop
{ my $x; }
####
# 17
while (1) { my $k; }
####
# 18
my ($x,@a);
$x=1 for @a;
>>>>
my($x, @a);
$x = 1 foreach (@a);
####
# 19
for (my $i = 0; $i +< 2;) {
    my $z = 1;
}
####
# 20
for (my $i = 0; $i +< 2; ++$i) {
    my $z = 1;
}
####
# 21
for (my $i = 0; $i +< 2; ++$i) {
    my $z = 1;
}
####
# 22
my $i;
while ($i) { my $z = 1; } continue { $i = 99; }
####
# 23
foreach my $i (1, 2) {
    my $z = 1;
}
####
# 24
my $i;
foreach $i (1, 2) {
    my $z = 1;
}
####
# 25
my $i;
foreach my $i (1, 2) {
    my $z = 1;
}
####
# 26
foreach my $i (1, 2) {
    my $z = 1;
}
####
# 27
foreach our $i (1, 2) {
    my $z = 1;
}
####
# 28
my $i;
foreach our $i (1, 2) {
    my $z = 1;
}
####
# 29
my @x;
print reverse sort(@x);
####
# 30
my @x;
print((sort {$b cmp $a} @x));
####
# 31
my @x;
print((reverse sort {$b <+> $a} @x));
####
# 32
print $_ foreach (reverse @main::a);
####
# 33
print $_ foreach (reverse 1, 2..5);
####
# 34  (bug #38684)
@main::ary = split(' ', 'foo', 0);
####
# 35 (bug #40055)
do { () }; 
####
# 36 (ibid.)
do { my $x = 1; $x }; 
####
# 37 <20061012113037.GJ25805@c4.convolution.nl>
my $f = sub {
    \%(\@());
} ;
####
# 38 (bug #43010)
'!@$%'->();
####
# 39 (ibid.)
::();
####
# 40 (ibid.)
'::::'->();
####
# 41 (ibid.)
&::::;
####
# 42
my $bar;
'Foo'->?$bar('orz');
####
# 43
'Foo'->bar('orz');
####
# 44
'Foo'->bar;
####
# 45
1; # was 'say'
####
# 46 state vars
state $x = 42;
####
# 47 state var assignment
{
    my $y = (state $x = 42);
}
>>>>
{
    my $y = state $x = 42;
}
####
# 48 state vars in anoymous subroutines
$main::a = sub {
    state $x;
    return $x++;
}
;
####
# 49 match
{
    $main::a =~ m/foo/;
}
####
# 51 Anonymous arrays and hashes, and references to them
my $a = \%();
my $b = \(\%());
my $c = \@();
my $d = \(\@());
####
# array slice
my @array;
@array[[1, 2]];
####
# hash slice
my %hash;
%hash{['foo', 'bar']};
