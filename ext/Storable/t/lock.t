#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

BEGIN {
    if (%ENV{PERL_CORE}){
	chdir('t') if -d 't';
	@INC = @('.', '../lib', '../ext/Storable/t');
    } else {
	unshift @INC, 't';
    }

    require 'st-dump.pl';
}

use Storable < qw(lock_store lock_retrieve);

unless (Storable::CAN_FLOCK()) {
    print "1..0 # Skip: fcntl/flock emulation broken on this platform\n";
    exit 0;
}

print "1..5\n";

my @a = @('first', undef, 3, -4, -3.14159, 456, 4.5);

#
# We're just ensuring things work, we're not validating locking.
#

ok 1, defined lock_store(\@a, 'store');
ok 2, my $dumped = &dump(\@a);

my $root = lock_retrieve('store');
ok 3, ref $root eq 'ARRAY';
ok 4, nelems(@a) == nelems(@$root);
ok 5, &dump($root) eq $dumped; 

unlink 't/store';

