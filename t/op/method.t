#!./perl

#
# test method calls and autoloading.
#

BEGIN {
    require "./test.pl";
}

print "1..57\n";

@A::ISA = 'B';
@B::ISA = 'C';

sub C::d {"C::d"}
sub D::d {"D::d"}

# First, some basic checks of method-calling syntax:
my $obj = bless [], "Pack";
sub Pack::method { shift; join(",", "method", @_) }
my $mname = "method";

is(Pack->method("a","b","c"), "method,a,b,c");
is(Pack->?$mname("a","b","c"), "method,a,b,c");

is(Pack->method(), "method");
is(Pack->?$mname(), "method");
is(Pack->method, "method");
is(Pack->?$mname, "method");

is($obj->method("a","b","c"), "method,a,b,c");
is($obj->?$mname("a","b","c"), "method,a,b,c");

is($obj->method(0), "method,0");
is($obj->method(1), "method,1");

is($obj->method(), "method");
is($obj->?$mname(), "method");
is($obj->method, "method");
is($obj->?$mname, "method");

is( A->d, "C::d");		# Update hash table;

*B::d = \&D::d;			# Import now.
is(A->d, "D::d");		# Update hash table;

{
    local @A::ISA = qw(C);	# Update hash table with split() assignment
    is(A->d, "C::d");
    $#A::ISA = -1;
    is(eval { A->d } || "fail", "fail");
}
is(A->d, "D::d");

{
    local *B::d;
    eval 'sub B::d {"B::d1"}';	# Import now.
    is(A->d, "B::d1");	# Update hash table;
    undef &B::d;
    is((eval { A->d }, ($@ =~ m/Undefined subroutine/)), 1);
}

is(A->d, "D::d");		# Back to previous state

eval 'sub B::d {"B::d2"}';	# Import now.
is(A->d, "B::d2");		# Update hash table;

# What follows is hardly guarantied to work, since the names in scripts
# are already linked to "pruned" globs. Say, `undef &B::d' if it were
# after `delete $B::{d}; sub B::d {}' would reach an old subroutine.

undef &B::d;
delete $B::{d};
is(A->d, "C::d");		# Update hash table;

eval 'sub B::d {"B::d3"}';	# Import now.
is(A->d, "B::d3");		# Update hash table;

delete $B::{d};
*dummy::dummy = sub {};		# Mark as updated
is(A->d, "C::d");

eval 'sub B::d {"B::d4"}';	# Import now.
is(A->d, "B::d4");		# Update hash table;

delete $B::{d};			# Should work without any help too
is(A->d, "C::d");

{
    local *C::d;
    is(eval { A->d } || "nope", "nope");
}
is(A->d, "C::d");

*A::x = *A::d;			# See if cache incorrectly follows synonyms
A->d;
is(eval { A->x } || "nope", "nope");

{
    # this test added due to bug discovery
    no strict 'refs';
    is(defined(@{*{Symbol::fetch_glob("unknown_package::ISA")}}) ? "defined" : "undefined", "undefined");
}

# test that failed subroutine calls don't affect method calls
{
    package A1;
    sub foo { "foo" }
    package A2;
    our @ISA = 'A1';
    package main;
    is(A2->foo(), "foo");
    is(do { eval 'A2::foo()'; $@ ? 1 : 0}, 1);
    is(A2->foo(), "foo");
}

## This test was totally misguided.  It passed before only because the
## code to determine if a package was loaded used to look for the hash
## %Foo::Bar instead of the package Foo::Bar:: -- and Config.pm just
## happens to export %Config.
#  {
#      is(do { use Config; eval 'Config->foo()';
#  	      $@ =~ m/^\QCan't locate object method "foo" via package "Config" at/ ? 1 : $@}, 1);
#      is(do { use Config; eval '$d = bless {}, "Config"; $d->foo()';
#  	      $@ =~ m/^\QCan't locate object method "foo" via package "Config" at/ ? 1 : $@}, 1);
#  }


# test error messages if method loading fails
is(do { eval 'my $e = bless {}, "E::A"; E::A->foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::A" at/ ? 1 : $@}, 1);
is(do { eval 'my $e = bless {}, "E::B"; $e->foo()';  
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::B" at/ ? 1 : $@}, 1);
is(do { eval 'E::C->foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::C" (perhaps / ? 1 : $@}, 1);

is(do { eval 'UNIVERSAL->E::D::foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::D" (perhaps / ? 1 : $@}, 1);
is(do { eval 'my $e = bless {}, "UNIVERSAL"; $e->E::E::foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::E" (perhaps / ? 1 : $@}, 1);

my $e = bless {}, "E::F";  # force package to exist
is(do { eval 'UNIVERSAL->E::F::foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::F" at/ ? 1 : $@}, 1);
is(do { eval '$e = bless {}, "UNIVERSAL"; $e->E::F::foo()';
	  $@ =~ m/^\QCan't locate object method "foo" via package "E::F" at/ ? 1 : $@}, 1);

# TODO: we need some tests for the SUPER:: pseudoclass

# failed method call or UNIVERSAL::can() should not autovivify packages
is( $::{"Foo::"} || "none", "none");  # sanity check 1
is( $::{"Foo::"} || "none", "none");  # sanity check 2

is( UNIVERSAL::can("Foo", "boogie") ? "yes":"no", "no" );
is( $::{"Foo::"} || "none", "none");  # still missing?

is( Foo->UNIVERSAL::can("boogie")   ? "yes":"no", "no" );
is( $::{"Foo::"} || "none", "none");  # still missing?

is( Foo->can("boogie")              ? "yes":"no", "no" );
is( $::{"Foo::"} || "none", "none");  # still missing?

is( eval 'Foo->boogie(); 1'         ? "yes":"no", "no" );
is( $::{"Foo::"} || "none", "none");  # still missing?

is(do { eval 'Foo->boogie()';
	  $@ =~ m/^\QCan't locate object method "boogie" via package "Foo" (perhaps / ? 1 : $@}, 1);

eval 'sub Foo::boogie { "yes, sir!" }';
is( $::{"Foo::"} ? "ok" : "none", "ok");  # should exist now
is( Foo->boogie(), "yes, sir!");

# TODO: universal.t should test NoSuchPackage->isa()/can()

# This is actually testing parsing of indirect objects and undefined subs
#   print foo("bar") where foo does not exist is not an indirect object.
#   print foo "bar"  where foo does not exist is an indirect object.

# Bug ID 20010902.002
is(
    eval q[
	our $x = 'x';
	sub Foo::x : lvalue { $x }
	Foo->?$x = 'ok';
    ] || $@, 'ok'
);

# [ID 20020305.025] PACKAGE::SUPER doesn't work anymore

package main;
our @X;
package Amajor;
sub test {
    push @main::X, 'Amajor', @_;
}
package Bminor;
use base qw(Amajor);
package main;
sub Bminor::test {
    $_[0]->Bminor::SUPER::test('x', 'y');
    push @main::X, 'Bminor', @_;
}
Bminor->test('y', 'z');
is("@X", "Amajor Bminor x y Bminor Bminor y z");
