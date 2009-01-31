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


use Storable < qw(store retrieve nstore);

use Test::More;
plan tests => 14;

$a = 'toto';
$b = \$a;
my $c = bless \%(), 'CLASS';
$c->{+attribute} = 'attrval';
my %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
my @a = @('first', '', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

ok defined store(\@a, 'store');
ok not  Storable::last_op_in_netorder();
ok defined nstore(\@a, 'nstore');
ok Storable::last_op_in_netorder();
ok Storable::last_op_in_netorder();

my $root = retrieve('store');
ok defined $root;
ok not  Storable::last_op_in_netorder();

my $nroot = retrieve('nstore');
ok defined $nroot;
ok Storable::last_op_in_netorder();

my $d1 = &dump($root);
ok 1;
my $d2 = &dump($nroot);
ok 1;

ok $d1 eq $d2; 

# Make sure empty string is defined at retrieval time
ok defined $root->[1];
ok not  length $root->[1];

END { 1 while unlink('store', 'nstore') }
