#!./perl -w
# tests state variables

BEGIN {
    require './test.pl';
}

use strict;
use feature "state";

plan tests => 58;

ok( ! defined state $uninit, q(state vars are undef by default) );

# basic functionality

sub stateful {
    state $x;
    state $y //= 1;
    my $z = 2;
    state ($t) //= 3;
    return  @($x++, $y++, $z++, $t++);
}

my ($x, $y, $z, $t) = < stateful();
is( $x, 0, 'uninitialized state var' );
is( $y, 1, 'initialized state var' );
is( $z, 2, 'lexical' );
is( $t, 3, 'initialized state var, list syntax' );

($x, $y, $z, $t) = < stateful();
is( $x, 1, 'incremented state var' );
is( $y, 2, 'incremented state var' );
is( $z, 2, 'reinitialized lexical' );
is( $t, 4, 'incremented state var, list syntax' );

($x, $y, $z, $t) = < stateful();
is( $x, 2, 'incremented state var' );
is( $y, 3, 'incremented state var' );
is( $z, 2, 'reinitialized lexical' );
is( $t, 5, 'incremented state var, list syntax' );

# in a nested block

sub nesting {
    state $foo //= 10;
    my $t;
    { state $bar //= 12; $t = ++$bar }
    ++$foo;
    return  @($foo, $t);
}

($x, $y) = < nesting();
is( $x, 11, 'outer state var' );
is( $y, 13, 'inner state var' );

($x, $y) = < nesting();
is( $x, 12, 'outer state var' );
is( $y, 14, 'inner state var' );

# in a closure

sub generator {
    my $outer;
    # we use $outer to generate a closure
    sub { ++$outer; ++state $x }
}

my $f1 = generator();
is( $f1->(), 1, 'generator 1' );
is( $f1->(), 2, 'generator 1' );
my $f2 = generator();
is( $f2->(), 1, 'generator 2' );
is( $f1->(), 3, 'generator 1 again' );
is( $f2->(), 2, 'generator 2 once more' );

# state variables are shared among closures

sub gen_cashier {
    my $amount = shift;
    state $cash_in_store;
    return \%(
	add => sub { $cash_in_store += $amount },
	del => sub { $cash_in_store -= $amount },
	bal => sub { $cash_in_store },
    );
}

gen_cashier(59)->{add}->();
gen_cashier(17)->{del}->();
is( gen_cashier()->{bal}->(), 42, '$42 in my drawer' );

# stateless assignment to a state variable

sub stateless {
    state $reinitme = 42;
    ++$reinitme;
}
is( stateless(), 43, 'stateless function, first time' );
is( stateless(), 43, 'stateless function, second time' );

# array state vars

sub stateful_array {
    state @x;
    push @x, 'x';
    return  (nelems @x)-1;
}

my $xsize = stateful_array();
is( $xsize, 0, 'uninitialized state array' );

$xsize = stateful_array();
is( $xsize, 1, 'uninitialized state array after one iteration' );

# hash state vars

sub stateful_hash {
    state %hx;
    return %hx{foo}++;
}

my $xhval = stateful_hash();
is( $xhval, 0, 'uninitialized state hash' );

$xhval = stateful_hash();
is( $xhval, 1, 'uninitialized state hash after one iteration' );

# Recursion

sub noseworth {
    my $level = shift;
    state $recursed_state = 123;
    is($recursed_state, 123, "state kept through recursion ($level)");
    noseworth($level - 1) if $level;
}
noseworth(2);

# Assignment return value

sub pugnax { my $x = state $y = 42; $y++; $x; }

is( pugnax(), 42, 'scalar state assignment return value' );



#
# Redefine.
#
{
    state $x = "one";
    no warnings;
    state $x = "two";
    is $x, "two", "masked"
}

# normally closureless anon subs share a CV and pad. If the anon sub has a
# state var, this would mean that it is shared. Check that this doesn't
# happen

{
    my @f;
    push @f, sub { state $x; ++$x } for 1..2;
    @f[0]->() for 1..10;
    is @f[0]->(), 11;
    is @f[1]->(), 1;
}

# each copy of an anon sub should get its own 'once block'

{
    my $x; # used to force a closure
    my @f;
    push @f, sub { $x=0; state $s ||= @_[0]; $s } for 1..2;
    is @f[0]->(1), 1;
    is @f[0]->(2), 1;
    is @f[1]->(3), 3;
    is @f[1]->(4), 3;
}




foreach my $forbidden (@(~< *DATA)) {
    chomp $forbidden;
    eval $forbidden;
    like $@->{description}, qr/Initialization of state variables in list context currently forbidden/, "Currently forbidden: $forbidden";
}

# [perl #49522] state variable not available

{
    my @warnings;
    local $^WARN_HOOK = sub { push @warnings, @_[0]->message };

    eval q{
	use warnings;

	sub f_49522 {
	    state $s = 88;
	    sub g_49522 { $s }
	    sub { $s };
	}

	sub h_49522 {
	    state $t = 99;
	    sub i_49522 {
		sub { $t };
	    }
	}
    };
    is $@, '', "eval f_49522";
    # shouldn't be any 'not available' or 'not stay shared' warnings
    ok !nelems @warnings, "suppress warnings part 1 [{join ' ',@warnings}]";

    @warnings = @( () );
    my $f = f_49522();
    is $f->(), 88, "state var closure 1";
    is g_49522(), 88, "state var closure 2";
    ok !nelems @warnings, "suppress warnings part 2 [{join ' ',@warnings}]";


    @warnings = @( () );
    $f = i_49522();
    h_49522(); # initialise $t
    is $f->(), 99, "state var closure 3";
    ok !nelems @warnings, "suppress warnings part 3 [{join ' ',@warnings}]";


}


__DATA__
state ($a) = 1;
(state $a) = 1;
state ($a, $b) = ();
state ($a, @b) = ();
(state $a, state $b) = ();
(state $a, $b) = ();
(state $a, my $b) = ();
(state $a, state @b) = ();
(state $a, local @b) = ();
(state $a, undef, state $b) = ();
state ($a, undef, $b) = ();
