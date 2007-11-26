#!./perl

BEGIN {
    chdir 't';
    @INC = '../lib';
    require './test.pl';
}

print "1..1\n";

use strict;

no strict 'vars';

$y = 1;
{
    my $y = 2;
    {
	our $y = $y;
	is($y, 2, 'our shouldnt be visible until introduced')
    }
}
