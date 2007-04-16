#!./perl
# Tests for caller()

BEGIN {
    require './test.pl';
    plan( tests => 77 );
}

my @c;

print "# Tests with caller(0)\n";

@c = caller(0);
ok( (!@c), "caller(0) in main program" );

eval { @c = caller(0) };
is( $c[3], "(eval)", "subroutine name in an eval {}" );
ok( !$c[4], "hasargs false in an eval {}" );

eval q{ @c = (Caller(0))[3] };
is( $c[3], "(eval)", "subroutine name in an eval ''" );
ok( !$c[4], "hasargs false in an eval ''" );

sub { @c = caller(0) } -> ();
is( $c[3], "main::__ANON__", "anonymous subroutine name" );
ok( $c[4], "hasargs true with anon sub" );

# Bug 20020517.003, used to dump core
sub foo { @c = caller(0) }
my $fooref = delete $::{foo};
$fooref -> ();
is( $c[3], "(unknown)", "unknown subroutine name" );
ok( $c[4], "hasargs true with unknown sub" );

print "# Tests with caller(1)\n";

sub f { @c = caller(1) }

sub callf { f(); }
callf();
is( $c[3], "main::callf", "subroutine name" );
ok( $c[4], "hasargs true with callf()" );
&callf;
ok( !$c[4], "hasargs false with &callf" );

eval { f() };
is( $c[3], "(eval)", "subroutine name in an eval {}" );
ok( !$c[4], "hasargs false in an eval {}" );

eval q{ f() };
is( $c[3], "(eval)", "subroutine name in an eval ''" );
ok( !$c[4], "hasargs false in an eval ''" );

sub { f() } -> ();
is( $c[3], "main::__ANON__", "anonymous subroutine name" );
ok( $c[4], "hasargs true with anon sub" );

sub foo2 { f() }
my $fooref2 = delete $::{foo2};
$fooref2 -> ();
is( $c[3], "(unknown)", "unknown subroutine name" );
ok( $c[4], "hasargs true with unknown sub" );

# See if caller() returns the correct warning mask

sub testwarn {
    my $w = shift;
    is( (caller(0))[9], $w, "warnings match caller");
}

# NB : extend the warning mask values below when new warnings are added
{
    use bytes;
    no warnings;
    BEGIN { is( ${^WARNING_BITS}, "\0" x 12, 'all bits off via "no warnings"' ) }
    testwarn("\0" x 12);

    use warnings;
    BEGIN { is( ${^WARNING_BITS}, "\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\025", 'default bits on via "use warnings"' ); }
    BEGIN { testwarn("\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\025", "#1"); }
    # run-time :
    # the warning mask has been extended by warnings::register
    testwarn("\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55");

    use warnings::register;
    BEGIN { is( ${^WARNING_BITS}, "\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55", 'warning bits on via "use warnings::register"' ) }
    testwarn("\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55","#3");
}


# The next two cases test for a bug where caller ignored evals if
# the DB::sub glob existed but &DB::sub did not (for example, if 
# $^P had been set but no debugger has been loaded).  The tests
# thus assume that there is no &DB::sub: if there is one, they 
# should both pass  no matter whether or not this bug has been
# fixed.

my $debugger_test =  q<
    my @stackinfo = caller(0);
    return scalar @stackinfo;
>;

sub pb { return (caller(0))[3] }

my $i = eval $debugger_test;
is( $i, 11, "do not skip over eval (and caller returns 10 elements)" );

is( eval 'pb()', 'main::pb', "actually return the right function name" );

my $saved_perldb = $^P;
$^P = 16;
$^P = $saved_perldb;

$i = eval $debugger_test;
is( $i, 11, 'do not skip over eval even if $^P had been on at some point' );
is( eval 'pb()', 'main::pb', 'actually return the right function name even if $^P had been on at some point' );

print "# caller can now return the compile time state of %^H\n";

sub hint_exists {
    my $key = shift;
    my $level = shift;
    my @results = caller($level||0);
    exists $results[10]->{$key};
}

sub hint_fetch {
    my $key = shift;
    my $level = shift;
    my @results = caller($level||0);
    $results[10]->{$key};
}

$::testing_caller = 1;

do './op/caller.pl' or die $@;
