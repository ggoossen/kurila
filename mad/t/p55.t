
# Test p55, the "Perl 5 to Perl 5" translator.

# The perl core should have MAD enabled ('sh Configure -Dmad=y ...')

# The part to convert xml to Perl 5 requires XML::Parser, but it does
# not depend on Perl internals, so you can use a stable system wide
# perl

# For the p55 on the perl test suite, it should be started from the
# $perlsource/t subdir

# Instructions:
#     sh Configure -Dmad=y
#     make && make test
#     cd t && /usr/bin/prove ../mad/t/p55.t

use 5.8.8;

use strict;
use warnings;

BEGIN {
    push @INC, "../mad";
}

use Test::More qw|no_plan|;
use Test::Differences;
use IO::Handle;

use Nomad;

my $version = "kurila-1.15";

sub p55 {
    my ($input, $msg) = @_;

    # perl5 to xml
    open my $infile, "> tmp.in";
    $infile->print($input);
    close $infile;

    unlink "tmp.xml";
    my $returncode = system("PERL_XMLDUMP='tmp.xml' ../perl -I ../lib tmp.in 2> tmp.err");

    if (-z "tmp.xml") {
        diag("failed dumping: '$input'");
        ok 0, "$msg" or $TODO or die;
        return;
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml", version => $version ) };
    diag($@) if $@;
    is($output, $input, $msg) or $TODO or die;
}

sub p55_file {
    my $file = shift;
    my $input;
    local $/ = undef;
    #warn $file;
    open(my $fh, "<", "$file") or die "Failed open '../t/$file' $!";
    $input = $fh->getline;
    close $fh or die;

    my $switches = "";
    if( $input =~ m/^[#][!].*perl(.*)/) {
        $switches = $1;
    }

    unlink "tmp.xml";
    my $returncode = system("PERL_XMLDUMP='tmp.xml' ../perl $switches -I ../lib $file 2> tmp.err > tmp.err");
    if (($returncode >> 8) == 2) {
        # exitcode '2' means a exit 0 in a BEGIN block.
      SKIP: { skip "$file has a 'exit 0' in a BEGIN block", 1; }
        return;
    }
    if ($returncode) {
        fail "MAD dump of '$file' failed.";
        return;
    }

    if (-z "tmp.xml") {
        fail "MAD dump failure of '$file'";
        return;
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml", version => $version ) };
    if ($@) {
        fail "convert xml to p5 failed file: '$file'";
        #$TODO or die;
        diag "error: $@";
        return;
    }
    # ok($output eq $input, "p55 '$file'");
    eq_or_diff $output, $input, "p55 '$file'";
}

undef $/;
my @prgs = split m/^########\n/m, <DATA>;

{
    use bytes;
    push @prgs, qq{# utf8 test\nuse bytes;\n"\xE8"};
}

use bytes;

for my $prog (@prgs) {
    my $msg = ($prog =~ s/^#(.*)\n//) && $1;
    local $TODO = ($msg =~ /TODO/) ? 1 : 0;
    p55($prog, $msg);
}

# Files
use File::Find;

our %failing = map { $_, 1 } qw|
../t/arch/64bitint.t
../t/run/switchp.t
|;

my @files;
find( sub { push @files, $File::Find::name if m/[.]t$/ }, '../t/');

$ENV{PERL_CORE} = 1;

for my $file (@files) {
    local $TODO = (exists $failing{$file} ? "Known failure" : undef);
    p55_file($file);
}

__DATA__
33
########
#ABC
Foo->new;
########
sub pi() { 3.14 }
my $x = pi;
########
-OS_Code => $a
########
sub ok($ok, $name) { }
#BEGIN { ok(1, 2, ); }
#######
#
s//$(m#.#)/g;
########
BEGIN { 1; }
########
# Reduced test case from t/io/layers.t
sub PerlIO::F_UTF8 () { 0x00008000 } # from perliol.h
BEGIN { PerlIO::Layer->find("encoding",1);}
########
# from t/op/getppid.t
pipe my ($r, $w)
########
# TODO exit in begin block. from t/op/threads.t without threads
BEGIN {
    exit 0;
}
use foobar;
########
1; # 1
2; # 2;
########
# operator with modify TARGET_MY
my ($nc_attempt, $within)  ;
$nc_attempt = 0+ ($within eq 'other_sub') ;
########
# __END__ section
my $foo

__END__
DATA
########
# split with PUSHRE
my @prgs = @( split "\n########\n", ~< *DATA );
########
# unless(eval { })
unless (try { $a }) { $a = $b }
########
# local our $...
local our $TODO
########
# 'my' inside prototyped subcall
sub ok($ok, ?$name) { }
ok my $x = "foobar";
########
# TODO do not execute CHECK block
CHECK { die; }
########
# new named method call syntax
my $bar;
Foo->?$bar();
########
# pod with invalid UTF-8
=head3 Gearman

I know Ask Bj�rn Hansen has implemented a transport for the C<gearman> distributed
job system, though it's not on CPAN at the time of writing this.

=cut
########
$^INCLUDE_PATH = @( qw(foo bar) );
########
if (int(1.23) == 1) { print \*STDOUT, "1"; } else { print \*STDOUT, "2"; }
########
# TODO state; op_once
state $x = 4;
########
my $x;
"$x->@"
########
$a =~ regex();
########
my ($foo, $bar);
s/foo/$bar/;
s/$foo/$bar/;
########
my ($foo, $bar);
$a =~ s/$foo/$bar/;
########
$a =~ s|(abc)|$(uc($1))|;
########
my $msg = "ce ºtii tu, bã ?\n"   ;
use utf8;
my $msg = "ce ºtii tu, bã ?\n";
########
(stat "abc")[2];
########
while ( ~< *DATA) {
      print \*STDOUT, $_;
}
########
for (1..5) {
    print \*STDOUT, $_;
}
########
map { $_ }, 1..5;
########
$( 3 );
########
sub () { 1 }
########
# assignment to hash
my %h;
%h = %(1, 2);
########
my %hash = %(1,2);
########
# hash expand assignment
my %h;
%( %< %h ) = %h;
########
do {
   # comment
}
########
try { }
########
# substitute with $(..)
my $str;
$str =~ s{(foo)}{$(sprintf("=\%02X", ord($1)))}g;
$str;
########
SKIP: do {
    print \*STDOUT, 1;
}
########
print \*STDOUT, "arg";
SKIP: do {
    print \*STDOUT, 1;
}
########
print \*STDOUT, "arg";
SKIP: do {
    print \*STDOUT, 1;
}    ;

sub foo {
    print \*STDOUT, "bar";
}
########
pos($a);
########
LABEL: for (@: 1) { warn "arg" }
########
# optional assignment
my @( ? $x) = qw();
########
# dotdotdot operator
my @($pw, ...) = qw(aap noot mies);
########
# or assignment.
my $a;
$a ||= 3;
########
# optional key
$a{?key};
########
# optional assignment with our
our $d;
@( ? $d) = qw();
########
# dynascope
dynascope;
########
# readpipe
readpipe;
########
# optional
push $a, $_ unless $a{$_};
########
# ;; at end of for loop
for my $x ($a) {
    do { 1 };;
}
########
# @( ... , ) assignment
@( $a, ) = $b;
########
@( ? $a->{x} ) = qw();
########
*F{IO} ;
########
$^WARNING += 1;
########
for our $_ ($a) {
    warn $_;
}
########
foo(1, , 2);
########
my %( 1 => $v, ...) = $a;
########
%() +%+ @();
########
%+: @: %();
########
sub ok($ok, ?$name) { return "$ok - $name"; }
########
my $sub = sub ($x) { ++$x; };
########
my %(aap => $aap, noot => $noot) = %();
########
sub (_) { 1 };
########
$^EVAL_ERROR =~ s/(?<=value attempted) at .*//s;
########
sub (?$foo) { $foo };
