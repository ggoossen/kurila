#!./perl

use warnings;

use feature ":5.10";
use Test::More tests => 50;

use B::Deparse;
my $deparse = B::Deparse->new();
ok($deparse);

# Tell B::Deparse about our ambient pragmas
do { my ($hint_bits, $warning_bits, $hinthash);
 BEGIN { @($hint_bits, $warning_bits, $hinthash) = @($^HINT_BITS, $^WARNING_BITS, \$^HINTS); }
 $deparse->ambient_pragmas (
     hint_bits    => $hint_bits,
     warning_bits => $warning_bits,
     '%^H'	  => $hinthash,
 );
};

$^INPUT_RECORD_SEPARATOR = "\n####\n";
while ( ~< *DATA) {
    chomp;
    my ($num, $testname, $todo);
    if (s/#\s*(.*)$//mg) {
        @($num, $todo, $testname) = @: $1 =~ m/(\d*)\s*(TODO)?\s*(.*)/;
    }
    my ($input, $expected);
    if (m/(.*)\n>>>>\n(.*)/s) {
	@($input, $expected) = @($1, $2);
    }
    else {
	@($input, $expected) = @($_, $_);
    }

    local our $TODO = $todo;

    my $coderef = eval "sub \{$input\}";

    if ($^EVAL_ERROR and $^EVAL_ERROR->{?description}) {
	diag("$num deparsed: $($^EVAL_ERROR->message)");
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
TODO: do {
    todo_skip("fix deparse", 4);
    my $deparsed_txt = "sub ".$deparse->coderef2text(\&c);
    my $deparsed_sub = eval $deparsed_txt; die if $^EVAL_ERROR;
    is($deparsed_sub->(), 'stuff');

    my $a = 0;
    is("\{\n    (-1) ** \$a;\n\}", $deparse->coderef2text(sub{(-1) ** $a }));

    use constant cr => \@('hello');
    my $string = "sub " . $deparse->coderef2text(\&cr);
    my $subref = eval $string;
    die "Failed eval '$string': $($^EVAL_ERROR->message)" if $^EVAL_ERROR;
    my $val = $subref->() or diag $string;
    is(ref($val), 'ARRAY');
    is($val->[0], 'hello');
};

my $Is_VMS = $^OS_NAME eq 'VMS';
my $Is_MacOS = $^OS_NAME eq 'MacOS';

my $path = join " ", map { qq["-I$_"] }, $^INCLUDE_PATH;
$path .= " -MMac::err=unix" if $Is_MacOS;
my $redir = $Is_MacOS ?? "" !! "2>&1";

$a = `$^EXECUTABLE_NAME $path "-MO=Deparse" -anlw -e 1 $redir`;
$a =~ s/-e syntax OK\n//g;
$a =~ s/.*possible typo.*\n//;	   # Remove warning line
$a =~ s{\\340\\242}{\\s} if (ord("\\") == 224); # EBCDIC, cp 1047 or 037
$a =~ s{\\274\\242}{\\s} if (ord("\\") == 188); # $^O eq 'posix-bc'
$b = <<'EOF';
BEGIN { $^WARNING = 1; }
BEGIN { $^INPUT_RECORD_SEPARATOR = "\n"; $^OUTPUT_RECORD_SEPARATOR = "\n"; }
LINE: while (defined($_ = ~< *ARGV)) {
    do {
        chomp $_;
        our @F = split(' ', $_, 0);
        '???'
    };
}
EOF
$b =~ s/(LINE:)/sub BEGIN \{
    'MacPerl'->bootstrap;
    'OSA'->bootstrap;
    'XL'->bootstrap;
\}
$1/ if $Is_MacOS;
do {
   local our $TODO = 1;
   is($a, $b);
};

#Re: perlbug #35857, patch #24505
#handle warnings::register-ed packages properly.
package B::Deparse::Wrapper;

use warnings;
use warnings::register;
sub getcode {
   my $deparser = B::Deparse->new();
   return $deparser->coderef2text(shift);
}

package main;

use warnings;
sub test {
   my $val = shift;
   my $res = B::Deparse::Wrapper::getcode($val);
   like( $res, qr/use warnings/);
}
sub testsub {
    42;
}
my ($q,$p);
my $x=sub { @( ++$q,++$p ) };
test($x);
eval <<EOFCODE and test($x);
   package bar;
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
do {
    no warnings;
    '???';
    2;
};
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
# 10
my $x;
print *STDOUT, $main::x;
####
# 11
my @x;
print *STDOUT, @main::x[1];
####
# 12
my %x;
%x{warn()};
####
# 0
@(my $x, my $y) = @('xx', 'yy');
####
my @x = @(1 .. 10);
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
s/x/$( 'y' )/;
####
# 16 - various lypes of loop
do { my $x };
>>>>
do { my $x; };
####
# 17 while loop
while (1) { my $k; }
####
# 18 postfix for loop
my ($x,@a);
$x=1 for @a;
>>>>
my($x, @a);
$x = 1 foreach (@a);
####
# 22
my $i;
while ($i) { my $z = 1; } continue { $i = 99; }
####
# 23 with my
foreach my $i (@(1, 2)) {
    my $z = 1;
}
####
# 27
foreach our $i (1) {
    my $z = 1;
}
####
# 28
my $i;
foreach our $i (1) {
    my $z = 1;
}
####
# 29
my @x;
print *STDOUT, reverse(sort(@x));
####
# 30
my @x;
print *STDOUT, (sort {$b cmp $a} , @x);
>>>>
my @x;
print *STDOUT, sort(sub { $main::b cmp $main::a; } , @x);
####
# 32
print *STDOUT, $_ foreach (reverse @main::a);
####
# 33 TODO range
print *STDOUT, $_ foreach (reverse 2 .. 5);
####
# 34  (bug #38684)
@main::ary = @(split(' ', 'foo', 0));
####
# 35 (bug #40055)
do { () }; 
>>>>
do { (); }; 
####
# 36 (ibid.)
do { my $x = 1; $x; }; 
####
# 37 <20061012113037.GJ25805@c4.convolution.nl>
my $f = sub {
    \%(\@());
} ;
####
# 38 (bug #43010)
'!@$%'->();
####
#
&'::'->();
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
# 49 match
do {
    $main::a =~ m/foo/;
};
####
# 51 Anonymous arrays and hashes, and references to them
my $a = \%();
my $b = \(\%());
my $c = \@();
my $d = \(\@());
####
# array slice
my @array;
@array[[@(1, 2)]];
####
# hash slice
my %hash;
%hash{[@('foo', 'bar')]};
####
testsub();
####
my($x, $y);
if ($x) {
    $y;
} else {
    $y * $y;
}
####
my($x, $y, $z);
$x = $y || $y;
