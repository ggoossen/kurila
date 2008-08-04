#!./perl

# ** DO NOT ADD ANY MORE TESTS HERE **
# Instead, put the test in the appropriate test file and use the 
# fresh_perl_is()/fresh_perl_like() functions in t/test.pl.

# This is for tests that used to abnormally cause segfaults, and other nasty
# errors that might kill the interpreter and for some reason you can't
# use an eval().

BEGIN {
    require './test.pl';	# for which_perl() etc
}

use strict;

my $Perl = which_perl();

$|=1;

my @prgs = @( () );
while( ~< *DATA) { 
    if(m/^#{8,}\s*(.*)/) { 
        push @prgs, \@('', $1);
    }
    else { 
        @prgs[-1]->[0] .= $_;
    }
}
plan tests => scalar nelems @prgs;

foreach my $prog (< @prgs) {
    my($raw_prog, $name) = < @$prog;

    my $switch;
    if ($raw_prog =~ s/^\s*(-\w.*)\n//){
	$switch = $1;
    }

    my($prog,$expected) = split(m/\nEXPECT\n/, $raw_prog);
    $prog .= "\n";
    $expected = '' unless defined $expected;

    if ($prog =~ m/^\# SKIP: (.+)/m) {
	if (eval $1) {
	    ok(1, "Skip: $1");
	    next;
	}
    }

    $expected =~ s/\n+$//;

    fresh_perl_is($prog, $expected, \%( switches => \@($switch || '') ), $name);
}

__END__
########
our $cusp = ^~^0 ^^^ (^~^0 >> 1);
use integer;
$, = " ";
print +($cusp - 1) % 8, $cusp % 8, -$cusp % 8, 8 ^|^ (($cusp + 1) % 8 + 7), "!\n";
EXPECT
7 0 0 8 !
########
our $foo=undef; $foo->go;
EXPECT
Can't call method "go" on UNDEF at - line 1.
########
BEGIN
        {
	    "foo";
        }
########
our @array;
@array[128]=1
########
our $x=0x0eabcd; print $x->ref;
EXPECT
Can't locate object method "ref" via package "961485" (perhaps you forgot to load "961485"?) at - line 1.
########
our $str;
chop ($str .= ~< *DATA);
########
our ($x, $y);
$x=2;$y=3;$x+<$y ? $x : $y += 23;print $x;
EXPECT
25
########
eval 'sub bar {print "In bar"}';
########
system './perl -ne "print if eof" /dev/null' unless $^O eq 'MacOS'
########
our $file;
chop($file = ~< *DATA);
########
package N;
sub new {my ($obj,$n)=@_; bless \$n}  
our $aa=N->new(1);
$aa=12345;
print $aa;
EXPECT
12345
########
$_="foo";
printf(STDOUT "\%s\n", $_);
EXPECT
foo
########
our @a;
push(@a, 1, 2, 3,)
########
quotemeta ""
########
package FOO;sub new {bless \%(FOO => 'BAR')};
package main;
use strict 'vars';   
my $self = FOO->new();
print %$self{FOO};
EXPECT
BAR
########
$_="foo";
s/.{1}//s;
print;
EXPECT
oo
########
sub by_number { $a <+> $b; };# inline function for sort below
our %as_ary;
%as_ary{0}="a0";
our @ordered_array=sort by_number keys(%as_ary);
########
BEGIN { die "phooey" }
EXPECT
phooey at - line 1.
BEGIN failed--compilation aborted
########
BEGIN { 1/0 }
EXPECT
Illegal division by zero at - line 1.
BEGIN failed--compilation aborted
########
BEGIN { undef = 0 }
EXPECT
Modification of a read-only value attempted at - line 1.
BEGIN failed--compilation aborted
########
my @a; @a[2] = 1; for (<@a) { $_ = 2 } print "{join ' ', <@a}\n"
EXPECT
2 2 2
########
# used to attach defelem magic to all immortal values,
# which made restore of local $_ fail.
foo(2+>1);
sub foo { bar() for <@_;  }
sub bar { local $_; }
print "ok\n";
EXPECT
ok
########
print "ok\n" if ("\0" cmp "\x[FF]") +< 0;
EXPECT
ok
########
open(H,"<",$^O eq 'MacOS' ? ':run:fresh_perl.t' : 'run/fresh_perl.t'); # must be in the 't' directory
stat(H);
print "ok\n" if (-e _ and -f _ and -r _);
EXPECT
ok
########
my $a = 'outer';
eval q[ my $a = 'inner'; eval q[ print "$a " ] ];
try { my $x = 'peace'; eval q[ print "$x\n" ] }
EXPECT
inner peace
########
-w
$| = 1;
sub foo {
    print "In foo1\n";
    eval 'sub foo { print "In foo2\n" }';
    print "Exiting foo1\n";
}
foo;
foo;
EXPECT
In foo1
Subroutine foo redefined at (eval 1) line 1.
    (eval) called at - line 4.
    main::foo called at - line 7.
Exiting foo1
In foo2
########
our $s = 0;
map {#this newline here tickles the bug
$s += $_} (1,2,4);
print "eat flaming death\n" unless ($s == 7);
########
BEGIN { @ARGV = @( qw(a b c d e) ) }
BEGIN { print "argv <{join ' ', <@ARGV}>\nbegin <",shift,">\n" }
END { print "end <",shift,">\nargv <{join ' ', <@ARGV}>\n" }
INIT { print "init <",shift,">\n" }
CHECK { print "check <",shift,">\n" }
EXPECT
argv <a b c d e>
begin <a>
check <b>
init <c>
end <d>
argv <e>
########
-l
# fdopen from a system descriptor to a system descriptor used to close
# the former.
open STDERR, '>&=', \*STDOUT or die $!;
select STDOUT; $| = 1; print fileno STDOUT or die $!;
select STDERR; $| = 1; print fileno STDERR or die $!;
EXPECT
1
2
########
-w
sub testme { my $a = "test"; { local $a = "new test"; print $a }}
EXPECT
Can't localize lexical variable $a at - line 1.
########
# TODO
package X;
sub ascalar { my $r; bless \$r }
sub DESTROY { print "destroyed\n" };
package main;
*s = X->ascalar();
EXPECT
destroyed
########
# TODO
package X;
sub anarray { bless \@() }
sub DESTROY { print "destroyed\n" };
package main;
*a = X->anarray();
EXPECT
destroyed
########
# TODO
package X;
sub ahash { bless \%() }
sub DESTROY { print "destroyed\n" };
package main;
*h = X->ahash();
EXPECT
destroyed
########
# TODO
package X;
sub aclosure { my $x; bless sub { ++$x } }
sub DESTROY { print "destroyed\n" };
package main;
*c = X->aclosure;
EXPECT
destroyed
########
# TODO
no strict "refs";
package X;
sub any { bless \%() }
my $f = "FH000"; # just to thwart any future optimisations
sub afh { select select *{Symbol::fetch_glob(++$f)};
          my $r = *{Symbol::fetch_glob($f)}{IO}; delete Symbol::stash('X')->{$f}; bless $r }
sub DESTROY { print "destroyed\n" }
package main;
print "start\n";
our $x = X->any(); # to bump sv_objcount. IO objs aren't counted??
*f = X->afh();
EXPECT
start
destroyed
destroyed
########
BEGIN {
  $| = 1;
  $^WARN_HOOK = sub {
    try { print @_[0]->{description} };
    die "bar";
  };
  warn "foo\n";
}
EXPECT
foo
bar at - line 5.
    main::__ANON__ called at - line 7.
BEGIN failed--compilation aborted
########
re();
sub re {
    my $re = join '', eval 'qr/(??{ $obj->method })/';
    $re;
}
EXPECT
########
use strict;
my $foo = "ZZZ\n";
END { print $foo }
EXPECT
ZZZ
########
eval '
use strict;
my $foo = "ZZZ\n";
END { print $foo }
';
EXPECT
ZZZ
########
-w
if (@ARGV) { print "" }
else {
  our $x;
  if ($x == 0) { print "" } else { print $x }
}
EXPECT
Use of uninitialized value $main::x in numeric eq (==) at - line 4.
########
our $x = sub {};
foo();
sub foo { try { return }; }
print "ok\n";
EXPECT
ok
########
sub f { my $a = 1; my $b = 2; my $c = 3; my $d = 4; next }
my $x = "foo";
{ f } continue { print $x, "\n" }
EXPECT
foo
########
sub C () { 1 }
sub M { @_[0] = 2; }
eval "C";
M(C);
EXPECT
Modification of a read-only value attempted at - line 2.
    main::M called at - line 4.
########
print qw(ab a\b a\\b);
EXPECT
aba\ba\\b
########
# lexicals declared after the myeval() definition should not be visible
# within it
our $foo;
sub myeval { eval @_[0] }
$foo = "ok 2\n";
myeval('sub foo { local $foo = "ok 1\n"; print $foo; }');
die $@ if $@;
foo();
print $foo;
EXPECT
ok 1
ok 2
########
# lexicals outside an eval"" should be visible inside subroutine definitions
# within it
eval <<'EOT'; die $@ if $@;
{
    my $X = "ok\n";
    eval 'sub Y { print $X }'; die $@ if $@;
    Y();
}
EOT
EXPECT
ok
########
# [ID 20001202.002] and change #8066 added 'at -e line 1';
# reversed again as a result of [perl #17763]
die qr(x)
EXPECT
recursive die at - line 3.
########
# David Dyck
# coredump in 5.7.1
close STDERR; die;
EXPECT
########
# core dump in 20000716.007
-w
"x" =~ m/(\G?x)?/;
########
# Bug 20010515.004
my @h = @(1 .. 10);
bad(<@h);
sub bad {
   undef @h;
   print "O";
   print for <@_;
   print "K";
}
EXPECT
OK
########
# Bug 20010506.041
use utf8;
"abcd\x{1234}" =~ m/(a)(b[c])(d+)?/i and print "ok\n";
EXPECT
ok
######## (?{...}) compilation bounces on PL_rs
-0
our $x;
{
  m/(?{ $x })/;
  # {
}
BEGIN { print "ok\n" }
EXPECT
ok
######## scalar ref to file test operator segfaults on 5.6.1 [ID 20011127.155]
# This only happens if the filename is 11 characters or less.
my $foo = \-f "blah";
print "ok" if ref $foo && !$$foo;
EXPECT
ok
######## [ID 20011128.159] 'X' =~ m/\X/ segfault in 5.6.1
print "ok" if 'X' =~ m/\X/;
EXPECT
ok
######## example from Camel 5, ch. 15, pp.406 (with my)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
my $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $人, "\n";
EXPECT
3
######## example from Camel 5, ch. 15, pp.406 (with our)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
our $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $人, "\n";
EXPECT
3
######## example from Camel 5, ch. 15, pp.406 (with package vars)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
our $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $人, "\n";
EXPECT
3
########
# test that closures generated by eval"" hold on to the CV of the eval""
# for their entire lifetime
our $x;
our $code = eval q[
  sub { eval '$x = "ok 1\n"'; }
];
&{$code}();
print $x;
EXPECT
ok 1
######## [ID 20020623.009] nested eval/sub segfaults
our $eval = eval 'sub { eval q|sub { %S }| }';
$eval->(\%());
######## "Segfault using HTML::Entities", Richard Jolly <richardjolly@mac.com>, <A3C7D27E-C9F4-11D8-B294-003065AE00B6@mac.com> in perl-unicode@perl.org
-lw
# SKIP: use Config; %ENV{PERL_CORE_MINITEST} or " %Config::Config{'extensions'} " !~ m[ Encode ] # Perl configured without Encode module
BEGIN {
  eval 'require Encode';
  if ($@) { exit 0 } # running minitest?
}
# Test case cut down by jhi
use Carp;
$^WARN_HOOK = sub { $@ = shift };
use Encode;
use utf8;
my $t = "\x[E9]";
$t =~ s/([^a])/{''}/g;
$@ =~ s/ at .*/ at/;
print $@;
print "Good" if $t eq "\x[E9]";
EXPECT

Good
