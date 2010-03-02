#!perl

use Config

BEGIN 
    # Can we load the version module ?
    try { require version; 1 } or do
        print: $^STDOUT, "1..0 # no version.pm\n"
        exit 0
    
    delete $^INCLUDED{"version.pm"}


use Test::More
use Safe
plan: tests => 1

my $c = Safe->new
$c->permit:  <qw(require caller entereval unpack)
my $r = $c->reval: q{ use version; 1 }
ok:  defined $r, "Can load version.pm in a Safe compartment"  or diag: $^EVAL_ERROR->{?description}
