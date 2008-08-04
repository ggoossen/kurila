#!./perl

# Add new tests to the end with format:
# ########
#
# # test description
# Test code
# EXPECT
# Warn or die msgs (if any) at - line 1234
#

$|=1;

undef $/;
our @prgs = @( split m/^########\n/m, ~< *DATA );

BEGIN { require './test.pl'; }
plan(tests => scalar nelems @prgs);
my $i;
for (< @prgs){
    ++$i;
    my($prog,$expected) = split(m/\nEXPECT\n/, $_, 2);
    print("not ok $i # bad test format\n"), next
        unless defined $expected;
    my ($testname) = $prog =~ m/^# (.*)\n/m;
    $testname ||= '';
    local our $TODO = $testname =~ s/^TODO //;
    $expected =~ s/\n+$//;

    fresh_perl_is($prog, $expected, \%(), $testname);
}

__END__

# standard behaviour, without any extra references
use Tie::Hash ;
our %h;
tie our %h, 'Tie::StdHash';
untie %h;
EXPECT
########

# standard behaviour, without any extra references
use Tie::Hash ;
{package Tie::HashUntie;
 use base 'Tie::StdHash';
 sub UNTIE
  {
   warn "Untied";
  }
}
our %h;
tie %h, 'Tie::HashUntie';
untie %h;
EXPECT
Untied at - line 8.
    Tie::HashUntie::UNTIE called at - line 13.
########

# standard behaviour, with 1 extra reference
use Tie::Hash ;
our $a = tie our %h, 'Tie::StdHash';
untie %h;
EXPECT
########

# standard behaviour, with 1 extra reference via tied
use Tie::Hash ;
tie our %h, 'Tie::StdHash';
our $a = tied %h;
untie %h;
EXPECT
########

# standard behaviour, with 1 extra reference which is destroyed
use Tie::Hash ;
our $a = tie our %h, 'Tie::StdHash';
$a = 0 ;
untie %h;
EXPECT
########

# standard behaviour, with 1 extra reference via tied which is destroyed
use Tie::Hash ;
tie our %h, 'Tie::StdHash';
our $a = tied %h;
$a = 0 ;
untie %h;
EXPECT
########

# strict behaviour, without any extra references
use warnings 'untie';
use Tie::Hash ;
tie our %h, 'Tie::StdHash';
untie %h;
EXPECT
########

# strict behaviour, with 1 extra references generating an error
use warnings 'untie';
use Tie::Hash ;
our $a = tie our %h, 'Tie::StdHash';
untie %h;
EXPECT
untie attempted while 1 inner references still exist at - line 6.
########

# strict behaviour, with 1 extra references via tied generating an error
use warnings 'untie';
use Tie::Hash ;
tie our %h, 'Tie::StdHash';
our $a = tied %h;
untie %h;
EXPECT
untie attempted while 1 inner references still exist at - line 7.
########

# strict behaviour, with 1 extra references which are destroyed
use warnings 'untie';
use Tie::Hash ;
our $a = tie our %h, 'Tie::StdHash';
$a = 0 ;
untie %h;
EXPECT
########

# strict behaviour, with extra 1 references via tied which are destroyed
use warnings 'untie';
use Tie::Hash ;
tie our %h, 'Tie::StdHash';
$a = tied %h;
$a = 0 ;
untie %h;
EXPECT
########

# strict error behaviour, with 2 extra references
use warnings 'untie';
use Tie::Hash ;
$a = tie our %h, 'Tie::StdHash';
$b = tied %h ;
untie %h;
EXPECT
untie attempted while 2 inner references still exist at - line 7.
########

# strict behaviour, check scope of strictness.
no warnings 'untie';
use Tie::Hash ;
our ($A, $B, $C);
our %H;
$A = tie our %h, 'Tie::StdHash';
$C = $B = tied %H ;
{
    use warnings 'untie';
    use Tie::Hash ;
    tie %h, 'Tie::StdHash';
    untie %h;
}
untie %H;
EXPECT
########

# Forbidden aggregate self-ties
sub Self::TIEHASH { bless @_[1], @_[0] }
{
    my %c;
    tie %c, 'Self', \%c;
}
EXPECT
Self-ties of arrays and hashes are not supported at - line 6.
########

# correct unlocalisation of tied hashes (patch #16431)
use Tie::Hash ;
tie our %tied, 'Tie::StdHash';
our %hash;
{ local %hash{'foo'} } warn "plain hash bad unlocalize" if exists %hash{'foo'};
{ local %tied{'foo'} } warn "tied hash bad unlocalize" if exists %tied{'foo'};
{ local %ENV{'foo'}  } warn "\%ENV bad unlocalize" if exists %ENV{'foo'};
EXPECT
########

# An attempt at lvalueable barewords broke this
tie FH, 'main';
EXPECT
Can't modify constant item in tie at - line 3, near "'main';"
Bareword "FH" not allowed while "strict subs" in use at - line 3, at EOF
Execution of - aborted due to compilation errors. at - line 3.
########

# localizing tied hash slices
%ENV{FooA} = 1;
%ENV{FooB} = 2;
print exists %ENV{FooA} ? 1 : 0, "\n";
print exists %ENV{FooB} ? 2 : 0, "\n";
print exists %ENV{FooC} ? 3 : 0, "\n";
{
    local %ENV{[qw(FooA FooC)]} = ();
    print exists %ENV{FooA} ? 4 : 0, "\n";
    print exists %ENV{FooB} ? 5 : 0, "\n";
    print exists %ENV{FooC} ? 6 : 0, "\n";
}
print exists %ENV{FooA} ? 7 : 0, "\n";
print exists %ENV{FooB} ? 8 : 0, "\n";
print exists %ENV{FooC} ? 9 : 0, "\n"; # this should not exist
EXPECT
1
2
0
4
5
6
7
8
0
########

#  [20020716.007] - nested FETCHES

sub F3::TIEHASH { bless \@(), 'F3' }
sub F3::FETCH { 1 }
my %f3;
tie %f3, 'F3';

sub F4::TIEHASH { bless \@(3), 'F4' }
sub F4::FETCH { my $self = shift; my $x = %f3{3}; $self }
my %f4;
tie %f4, 'F4';

print %f4{'foo'}->[0],"\n";

EXPECT
3
########
# the tmps returned by FETCH should appear to be SCALAR
# (even though they are now implemented using PVLVs.)
package X;
sub TIEHASH { bless \%() }
sub FETCH {1}
my (%h, @a);
tie %h, 'X';
my $r1 = \%h{1};
my $s = ref($r1);
$s=~ s/\(0x\w+\)//g;
print $s, "\n";
EXPECT
SCALAR
########
# TODO Bug 36267

sub TIEHASH  { bless \%(), @_[0] }
sub STORE    { @_[0]->{@_[1]} = @_[2] }
sub FIRSTKEY { my $a = scalar keys %{@_[0]}; each %{@_[0]} }
sub NEXTKEY  { each %{@_[0]} }
sub DELETE   { delete @_[0]->{@_[1]} }
sub CLEAR    { %{@_[0]} = %() }
our %h;
our %i;
%h{b}=1;
delete %h{b};
print nelems(@(keys %h)), "\n";
tie %h, 'main';
%i{a}=1;
%h = %i;
untie %h;
print nelems(@(keys %h)), "\n";
EXPECT
0
0
########
our %h;
sub TIEHASH { bless \@(), 'main' }
{
    local %h;
    tie %h, 'main';
}
print "tied\n" if tied %h;
EXPECT
