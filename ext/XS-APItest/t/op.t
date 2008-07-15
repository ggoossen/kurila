#!perl -w

use TestInit;
use Config;

BEGIN {
  if (%Config{'extensions'} !~ m/\bXS\/APItest\b/) {
    # Look, I'm using this fully-qualified variable more than once!
    print "1..0 # Skip: XS::APItest was not built\n";
    exit 0;
  }
}

use strict;
use utf8;
use Test::More 'no_plan';

use_ok('XS::APItest');

