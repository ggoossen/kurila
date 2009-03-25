#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#
# Original Author: Ulrich Pfeifer
# (C) Copyright 1997, Universitat Dortmund, all rights reserved.
#

use Storable < qw(store retrieve);

# problems with 5.00404 when in an BEGIN block, so this is defined here
if (!try { require File::Spec; 1 } || $File::Spec::VERSION +< 0.8) {
    print $^STDOUT, "1..0 # Skip: File::Spec 0.8 needed\n";
    exit 0;
    # Mention $File::Spec::VERSION again, as 5.00503's harness seems to have
    # warnings on.
    exit $File::Spec::VERSION;
}

print $^STDOUT, "1..8\n";

my $test = 1;
*GLOB = *GLOB; # peacify -w
my $bad = \@('foo', \*GLOB,  'bar');
my $result;

try {$result = store ($bad , 'store')};
print ($^STDOUT, (!defined $result)??"ok $test\n"!!"not ok $test\n"); $test++;
print ($^STDOUT, $^EVAL_ERROR??"ok $test\n"!!"not ok $test\n"); $test++;

$Storable::forgive_me=1;

my $devnull = File::Spec->devnull;

open(my $saverr, ">&", $^STDERR);
open($^STDERR, ">", "$devnull") or 
  ( print $saverr, "Unable to redirect STDERR: $^OS_ERROR\n" and exit(1) );

try {$result = store ($bad , 'store')};

open($^STDERR, ">&", \*$saverr);

print ($^STDOUT, (defined $result)??"ok $test\n"!!"not ok $test\n"); $test++;
print ($^STDOUT, ($^EVAL_ERROR eq '')??"ok $test\n"!!"not ok $test\n"); $test++;

my $ret = retrieve('store');
print ($^STDOUT, (defined $ret)??"ok $test\n"!!"not ok $test\n"); $test++;
print ($^STDOUT, ($ret->[0] eq 'foo')??"ok $test\n"!!"not ok $test\n"); $test++;
print ($^STDOUT, ($ret->[2] eq 'bar')??"ok $test\n"!!"not ok $test\n"); $test++;
print ($^STDOUT, (ref $ret->[1] eq 'SCALAR')??"ok $test\n"!!"not ok $test\n"); $test++;


END { 1 while unlink 'store' }
