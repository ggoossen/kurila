#!perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

use strict; use warnings;
use Test::More;
my $n_tests;

use Hash::Util::FieldHash;
use Scalar::Util qw( weaken);

# The functions in Hash::Util::FieldHash
# _test_uvar_get, _test_uvar_get and _test_uvar_both

# _test_uvar_get( $anyref, \ $counter) makes the referent of $anyref
# "uvar"-magical with get magic only.  $counter is reset if the magic
# could be established.  $counter will be incremented each time the
# magic "get" function is called.

# _test_uvar_set does the same for "set" magic.  _test_uvar_both
# sets both magic functions identically.  Both use the same counter.

# magical weak ref (patch to sv.c)
{
    my( $magref, $counter);

    $counter = 123;
    Hash::Util::FieldHash::_test_uvar_set( \ $magref, \ $counter);
    is( $counter, 0, "got magical scalar");

    my $ref = [];
    $magref = $ref;
    is( $counter, 1, "store triggers magic");

    weaken $magref;
    is( $counter, 1, "weaken doesn't trigger magic");
    
    { my $x = $magref }
    is( $counter, 1, "read doesn't trigger magic");

    undef $ref;
    is( $counter, 2, "ref expiry triggers magic (weakref patch worked)");

    is( $magref, undef, "weak ref works normally");

    # same, but overwrite weakref before expiry
    $counter = 0;
    weaken( $magref = $ref = []);
    is( $counter, 1, "setup for overwrite");

    $magref = my $other_ref = [];
    is( $counter, 2, "overwrite triggers");
    
    undef $ref;
    is( $counter, 2, "ref expiry doesn't trigger after overwrite");

    is( $magref, $other_ref, "weak ref doesn't kill overwritten value");

    BEGIN { $n_tests += 10 }
}

# magical hash (patches to mg.c and hv.c)
{
    # the hook is only sensitive if the set function is NULL
    my ( %h, $counter);
    $counter = 123;
    Hash::Util::FieldHash::_test_uvar_get( \ %h, \ $counter);
    is( $counter, 0, "got magical hash");

    %h = ( abc => 123);
    is( $counter, 1, "list assign triggers");

    $h{ def} = 456;
    is( $counter, 3, "lvalue assign triggers twice");

    exists $h{ def};
    is( $counter, 4, "good exists triggers");

    exists $h{ xyz};
    is( $counter, 5, "bad exists triggers");

    delete $h{ def};
    is( $counter, 6, "good delete triggers");

    delete $h{ xyz};
    is( $counter, 7, "bad delete triggers");

    my $x = $h{ abc};
    is( $counter, 8, "good read triggers");

    $x = $h{ xyz};
    is( $counter, 9, "bad read triggers");

    bless \ %h;
    is( $counter, 9, "bless triggers(!)");


    $x = keys %h;
    is( $counter, 9, "scalar keys doesn't trigger");

    () = keys %h;
    is( $counter, 9, "list keys doesn't trigger");

    $x = values %h;
    is( $counter, 9, "scalar values doesn't trigger");

    () = values %h;
    is( $counter, 9, "list values doesn't trigger");

    $x = each %h;
    is( $counter, 9, "scalar each doesn't trigger");

    () = each %h;
    is( $counter, 9, "list each doesn't trigger");

    # see that normal set magic doesn't trigger (identity condition)
    my %i;
    Hash::Util::FieldHash::_test_uvar_set( \ %i, \ $counter);
    is( $counter, 0, "got magical hash");

    %i = ( abc => 123);
    $i{ def} = 456;
    exists $i{ def};
    exists $i{ xyz};
    delete $i{ def};
    delete $i{ xyz};
    $x = $i{ abc};
    $x = $i{ xyz};
    $x = keys %i;
    () = keys %i;
    $x = values %i;
    () = values %i;
    $x = each %i;
    () = each %i;
    
    is( $counter, 0, "normal set magic never triggers");

    bless \ %i, 'abc';
    is( $counter, 1, "...except with bless");

    # see that magic with both set and get doesn't trigger (identity condition)
    $counter = 123;
    my %j;
    Hash::Util::FieldHash::_test_uvar_same( \ %j, \ $counter);
    is( $counter, 0, "got magical hash");

    %j = ( abc => 123);
    $j{ def} = 456;
    exists $j{ def};
    exists $j{ xyz};
    delete $j{ def};
    delete $j{ xyz};
    $x = $j{ abc};
    $x = $j{ xyz};
    $x = keys %j;
    () = keys %j;
    $x = values %j;
    () = values %j;
    $x = each %j;
    () = each %j;
    
    is( $counter, 0, "normal get magic never triggers");

    bless \ %j, 'abc';
    is( $counter, 1, "...except for bless");

    BEGIN { $n_tests += 22 }
}

BEGIN { plan tests => $n_tests }

