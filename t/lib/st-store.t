#!./perl

# $Id: store.t,v 0.7 2000/08/03 22:04:45 ram Exp $
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#
# $Log: store.t,v $
# Revision 0.7  2000/08/03 22:04:45  ram
# Baseline for second beta release.
#

sub BEGIN {
    chdir('t') if -d 't';
    unshift @INC, '../lib';
    require Config; import Config;
    if ($Config{'extensions'} !~ /\bStorable\b/) {
        print "1..0 # Skip: Storable was not built\n";
        exit 0;
    }
    require 'lib/st-dump.pl';
}


use Storable qw(store retrieve store_fd nstore_fd retrieve_fd);

print "1..20\n";

$a = 'toto';
$b = \$a;
$c = bless {}, CLASS;
$c->{attribute} = 'attrval';
%a = ('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
@a = ('first', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

print "not " unless defined store(\@a, 'store');
print "ok 1\n";

$dumped = &dump(\@a);
print "ok 2\n";

$root = retrieve('store');
print "not " unless defined $root;
print "ok 3\n";

$got = &dump($root);
print "ok 4\n";

print "not " unless $got eq $dumped; 
print "ok 5\n";

1 while unlink 'store';

package FOO; @ISA = qw(Storable);

sub make {
	my $self = bless {};
	$self->{key} = \%main::a;
	return $self;
};

package main;

$foo = FOO->make;
print "not " unless $foo->store('store');
print "ok 6\n";

print "not " unless open(OUT, '>>store');
print "ok 7\n";
binmode OUT;

print "not " unless defined store_fd(\@a, ::OUT);
print "ok 8\n";
print "not " unless defined nstore_fd($foo, ::OUT);
print "ok 9\n";
print "not " unless defined nstore_fd(\%a, ::OUT);
print "ok 10\n";

print "not " unless close(OUT);
print "ok 11\n";

print "not " unless open(OUT, 'store');
binmode OUT;

$r = retrieve_fd(::OUT);
print "not " unless defined $r;
print "ok 12\n";
print "not " unless &dump($foo) eq &dump($r);
print "ok 13\n";

$r = retrieve_fd(::OUT);
print "not " unless defined $r;
print "ok 14\n";
print "not " unless &dump(\@a) eq &dump($r);
print "ok 15\n";

$r = retrieve_fd(main::OUT);
print "not " unless defined $r;
print "ok 16\n";
print "not " unless &dump($foo) eq &dump($r);
print "ok 17\n";

$r = retrieve_fd(::OUT);
print "not " unless defined $r;
print "ok 18\n";
print "not " unless &dump(\%a) eq &dump($r);
print "ok 19\n";

eval { $r = retrieve_fd(::OUT); };
print "not " unless $@;
print "ok 20\n";

close OUT;
END { 1 while unlink 'store' }


