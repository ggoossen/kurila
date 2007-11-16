#!./perl

# Testing of v-string syntax

BEGIN {
    $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN };
}

$DOWARN = 1; # enable run-time warnings now

use Config;

require "./test.pl";
plan( tests => 15 );

use utf8;

eval 'use v5.5.640';
like( $@, qr/use VERSION is not valid in Perl Kurila/, "use v5.5.640;");

# printing characters should work
is(ref v111.107.32, 'version','ASCII printing characters');

# poetry optimization should also
sub v77 { "ok" }
$x = v77;
is('ok',$x,'poetry optimization');

# but not when dots are involved
$x = v77.78.79;
is($x, 'v77.78.79','poetry optimization with dots');

#
# now do the same without the "v"
eval 'use 5.8';
like( $@, qr/use VERSION is not valid in Perl Kurila/, "use 5.8");

eval 'use 5.5.640';
like( $@, qr/Too many decimal points/, "use 5.5.640" );

# hash keys too
eval "111.107.32";
like( $@, qr/Too many decimal points/ );

# See if the things Camel-III says are true: 29..33

# Chapter 28, pp671
ok(v5.6.0 lt v5.7.0, "v5.6.0 lt v5.7.0");

# part of 20000323.059
is(v200, +v200,         "v200 eq +v200"         );
is(v200, eval( "v200"), 'v200 eq "v200"'        );
is(v200, eval("+v200"), 'v200 eq eval("+v200")' );

# Tests for magic v-strings 

$v = v1.2_3;
is( ref($v), 'version', 'v-string objects with v' );

# [perl #16010]
%h = (v65 => 42);
ok( exists $h{v65}, "v-stringness is not engaged for vX" );
%h = (v65.66 => 42);
ok( exists $h{'v65.66'}, "v-stringness is engaged for vX.Y" );
eval ' %h = (65.66.67 => 42); ';
like($@, qr/Too many decimal points/);


