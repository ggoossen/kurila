#!/usr/local/bin/perl -w

use Storable < qw(nfreeze);
use HAS_OVERLOAD;

my $o = HAS_OVERLOAD->make("snow");
my $f = nfreeze \$o;

my $uu = pack 'u', $f;

print $uu;

