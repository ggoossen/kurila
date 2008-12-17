#!./perl

# "This IS structured code.  It's just randomly structured."

BEGIN {
    require "./test.pl";
}

use warnings;
plan tests => 16;
our $TODO;

# bug #9990 - don't prematurely free the CV we're &going to.

sub f1 {
    my $x;
    goto sub { $x=0; ok(1,"don't prematurely free CV\n") }
}
f1();

# [perl #29708] - goto &foo could leave foo() at depth two with
# @_ == PL_sv_undef, causing a coredump


my $r = runperl(
    prog =>
	'our $d; sub f { return if $d; $d=1; my $a=sub {goto &f}; &$a; f() } f(); print qq(ok\n)',
    stderr => 1
    );
is($r, "ok\n", 'avoid pad without an @_');

# Test autoloading mechanism.

sub two {
    my @($pack, $file, $line) =@( caller);	# Should indicate original call stats.
    is("$(join ' ',@_) $pack $file $line", "1 2 3 main $::FILE $::LINE",
	'autoloading mechanism.');
}

sub one {
    eval <<'END';
    no warnings 'redefine';
    sub one { pass('sub one'); goto &two; fail('sub one tail'); }
END
    goto &one;
}

$::FILE = __FILE__;
$::LINE = __LINE__ + 1;
&one(1,2,3);

do {
    my $wherever = 'NOWHERE';
    try { goto $wherever };
    like($@->{?description}, qr/goto must have sub/, 'goto NOWHERE sets $@');
};

# see if a modified @_ propagates
do {
  my $i;
  package Foo;
  sub DESTROY	{ my $s = shift; main::is($s->[0], $i, "destroy $i"); }
  sub show	{ main::is(nelems(@_), 5, "show $i",); }
  sub start	{ push @_, 1, "foo", \%(); goto &show; }
  for (1..3)	{ $i = $_; start(bless(\@($_)), 'bar'); }
};

# deep recursion with gotos eventually caused a stack reallocation
# which messed up buggy internals that didn't expect the stack to move

sub recurse1 {
    unshift @_, "x";
    no warnings 'recursion';
    goto &recurse2;
}
sub recurse2 {
    my $x = shift;
    @_[0] ?? 1 + recurse1(@_[0] - 1) !! 0
}
is(recurse1(500), 500, 'recursive goto &foo');

# [perl #32039] Chained goto &sub drops data too early. 

my $chained_goto_ok;
sub a32039 { @_=@("foo"); goto &b32039; }
sub b32039 { goto &c32039; }
sub c32039 { $chained_goto_ok = (@_[0] eq 'foo') }
a32039();
ok($chained_goto_ok, 'chained &goto');

# goto &foo not allowed in evals


sub null { 1 };
eval 'goto &null';
like($@->{?description}, qr/Can't goto subroutine from an eval-string/, 'eval string');
try { goto &null };
like($@->{?description}, qr/Can't goto subroutine from an eval-block/, 'eval block');

# [perl #36521] goto &foo in warn handler could defeat recursion avoider

do {
    my $r = runperl(
		stderr => 1,
		prog => 'my $d; my $w = sub { return if $d++; warn q(bar)}; local $^WARN_HOOK = sub { goto &$w; }; warn q(foo);'
    );
    like($r, qr/recursive die/, "goto &foo in warn");
};
