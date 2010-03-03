#!./perl

#
# test method calls and autoloading.
#

BEGIN 
    require "./test.pl"


plan: tests => 50

@A::ISA = @:  'B' 
@B::ISA = @:  'C' 

sub C::d {"C::d"}
sub D::d {"D::d"}

# First, some basic checks of method-calling syntax:
my $obj = bless: \$@, "Pack"
sub Pack::method { shift; (join: ",", (@:  "method", < @_)) }
my $mname = "method"

is: (Pack->method: "a","b","c"), "method,a,b,c"
is: (Pack->?$mname: "a","b","c"), "method,a,b,c"

is: Pack->method, "method"
is: (Pack->?$mname: ), "method"
is: Pack->method, "method"
is: (Pack->?$mname: ), "method"

is: ($obj->method: "a","b","c"), "method,a,b,c"
is: ($obj->?$mname: "a","b","c"), "method,a,b,c"

is: ($obj->method: 0), "method,0"
is: ($obj->method: 1), "method,1"

is: $obj->method, "method"
is: ($obj->?$mname: ), "method"
is: $obj->method, "method"
is: ($obj->?$mname: ), "method"

dies_like:  sub (@< @_) { (@: 1, 2)->method: }
            qr/Can't call method "method" on ARRAY/ 

is:  (A->d: ), "C::d"		# Update hash table;

*B::d = \&D::d			# Import now.
is: A->d, "D::d"		# Update hash table;

do
    local @A::ISA = qw(C)	# Update hash table with split() assignment
    is: A->d, "C::d"
    @A::ISA = @:  0 
    is: try { A->d } || "fail", "fail"

is: A->d, "D::d"

eval 'sub B::d {"B::d2"}'	# Import now.
is: A->d, "B::d2"		# Update hash table;

# What follows is hardly guarantied to work, since the names in scripts
# are already linked to "pruned" globs. Say, `undef &B::d' if it were
# after `delete $B::{d}; sub B::d {}' would reach an old subroutine.

undef &B::d
delete %B::{d}
is: A->d, "C::d"		# Update hash table;

eval 'sub B::d {"B::d3"}'	# Import now.
is: A->d, "B::d3"		# Update hash table;

delete %B::{d}
*dummy::dummy = sub {}		# Mark as updated
is: A->d, "C::d"

eval 'sub B::d {"B::d4"}'	# Import now.
is: A->d, "B::d4"		# Update hash table;

delete %B::{d}			# Should work without any help too
is: A->d, "C::d"

# test that failed subroutine calls don't affect method calls
do
    package A1
    sub foo { "foo" }
    package A2
    our @ISA = @:  'A1' 
    package main;
    is: A2->foo, "foo"
    is: do { eval 'A2::foo()'; $^EVAL_ERROR ?? 1 !! 0}, 1
    is: A2->foo, "foo"


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
is: do { eval 'my $e = bless: \$%, "E::A"; E::A->foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::A"/ ?? 1 !! ($^EVAL_ERROR->message: )}, 1
is: do { eval 'my $e = bless: \$%, "E::B"; $e->foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::B"/ ?? 1 !! $^EVAL_ERROR}, 1
is: do { eval 'E::C->foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::C" (perhaps / ?? 1 !! $^EVAL_ERROR}, 1

is: do { eval 'UNIVERSAL->E::D::foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::D" (perhaps / ?? 1 !! $^EVAL_ERROR}, 1
is: do { eval 'my $e = bless: \$%, "UNIVERSAL"; $e->E::E::foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::E" (perhaps / ?? 1 !! $^EVAL_ERROR}, 1

my $e = bless: \$%, "E::F"  # force package to exist
is: do { eval 'UNIVERSAL->E::F::foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::F"/ ?? 1 !! $^EVAL_ERROR}, 1
is: do { eval '$e = bless: \$%, "UNIVERSAL"; $e->E::F::foo';
        $^EVAL_ERROR->message =~ m/^\QCan't locate object method "foo" via package "E::F"/ ?? 1 !! $^EVAL_ERROR}, 1

# TODO: we need some tests for the SUPER:: pseudoclass

# failed method call or UNIVERSAL::can() should not autovivify packages
is:  %main::{?"Foo::"} || "none", "none"  # sanity check 1
is:  %main::{?"Foo::"} || "none", "none"  # sanity check 2

is:  (UNIVERSAL::can: "main::Foo", "boogie") ?? "yes"!!"no", "no" 
is:  %main::{?"Foo::"} || "none", "none"  # still missing?

is: ( main::Foo->UNIVERSAL::can: "boogie")   ?? "yes"!!"no", "no" 
is:  %main::{?"Foo::"} || "none", "none"  # still missing?

is:  (main::Foo->can: "boogie")              ?? "yes"!!"no", "no" 
is:  %main::{?"Foo::"} || "none", "none"  # still missing?

is:  eval 'main::Foo->boogie(); 1'         ?? "yes"!!"no", "no" 
is:  %main::{?"Foo::"} || "none", "none"  # still missing?

is: do { eval 'main::Foo->boogie';
        ($^EVAL_ERROR->message: ) =~ m/^\QCan't locate object method "boogie" via package "main::Foo" (perhaps / ?? 1 !! $^EVAL_ERROR}, 1

eval 'sub main::Foo::boogie { "yes, sir!" }'
is:  %main::{?"Foo::"} ?? "ok" !! "none", "ok"  # should exist now
is:  main::Foo->boogie, "yes, sir!"

# TODO: universal.t should test NoSuchPackage->isa()/can()

# [ID 20020305.025] PACKAGE::SUPER doesn't work anymore

package main
our @X
package Amajor
sub test
    push: @main::X, 'Amajor', < @_

package Bminor
use base < qw(Amajor)
package main
sub Bminor::test
    @_[0]->Bminor::SUPER::test: 'x', 'y'
    push: @main::X, 'Bminor', < @_

Bminor->test: 'y', 'z'
is: "$((join: ' ',@X))", "Amajor Bminor x y Bminor Bminor y z"
