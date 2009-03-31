#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

BEGIN {
    if (env::var('PERL_CORE')){
	chdir('t') if -d 't';
	$^INCLUDE_PATH = @('.', '../lib', '../ext/Storable/t');
    } else {
	unshift $^INCLUDE_PATH, 't';
    }

    require 'st-dump.pl';
}

use Storable < qw(lock_store lock_retrieve);

unless (Storable::CAN_FLOCK()) {
    print $^STDOUT, "1..0 # Skip: fcntl/flock emulation broken on this platform\n";
    exit 0;
}

use Test::More;
plan tests => 5;

my @a = @('first', undef, 3, -4, -3.14159, 456, 4.5);

#
# We're just ensuring things work, we're not validating locking.
#

ok defined lock_store(\@a, 'store');
ok(my $dumped = &dump(\@a));

my $root = lock_retrieve('store');
ok ref $root eq 'ARRAY';
ok nelems(@a) == nelems(@$root);
ok &dump($root) eq $dumped; 

unlink 't/store';

