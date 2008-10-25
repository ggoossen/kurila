#!./perl

BEGIN {
    require './test.pl';
}

print "1..1\n";

use strict;

our $y = 1;
do {
    my $y = 2;
    do {
	our $y = $y;
	is($y, 2, 'our shouldnt be visible until introduced')
    };
};
