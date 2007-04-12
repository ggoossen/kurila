#!./perl

# $Id: forgive.t,v 0.7.1.1 2000/08/03 22:04:45 ram Exp $
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#
# Original Author: Ulrich Pfeifer
# (C) Copyright 1997, Universitat Dortmund, all rights reserved.
#
# $Log: forgive.t,v $
# Revision 0.7.1.1  2000/08/03 22:04:45  ram
# Baseline for second beta release.
#
# Revision 0.7  2000/08/03 22:04:45  ram
# Baseline for second beta release.
#

sub BEGIN {
    chdir('t') if -d 't';
    require Config; import Config;
    if ($Config{'extensions'} !~ /\bStorable\b/) {
        print "1..0 # Skip: Storable was not built\n";
        exit 0;
    }
    unshift @INC, '../lib';
}

use Storable qw(store retrieve);

print "1..8\n";

my $test = 1;
my $bad = ['foo', sub { 1 },  'bar'];
my $result;

eval {$result = store ($bad , 'store')};
print ((!defined $result)?"ok $test\n":"not ok $test\n"); $test++;
print (($@ ne '')?"ok $test\n":"not ok $test\n"); $test++;

$Storable::forgive_me=1;

open(SAVEERR, ">&STDERR");
open(STDERR, ">/dev/null") or 
  ( print SAVEERR "Unable to redirect STDERR: $!\n" and exit(1) );

eval {$result = store ($bad , 'store')};

open(STDERR, ">&SAVEERR");

print ((defined $result)?"ok $test\n":"not ok $test\n"); $test++;
print (($@ eq '')?"ok $test\n":"not ok $test\n"); $test++;

my $ret = retrieve('store');
print ((defined $ret)?"ok $test\n":"not ok $test\n"); $test++;
print (($ret->[0] eq 'foo')?"ok $test\n":"not ok $test\n"); $test++;
print (($ret->[2] eq 'bar')?"ok $test\n":"not ok $test\n"); $test++;
print ((ref $ret->[1] eq 'SCALAR')?"ok $test\n":"not ok $test\n"); $test++;


END { unlink 'store' }
