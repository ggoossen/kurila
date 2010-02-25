#!/usr/bin/perl -w

# Test is_deeply and friends with circular data structures [rt.cpan.org 7289]

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 10

my $a1 = \@:  1, 2, 3 
push: $a1->@, $a1
my $a2 = \@:  1, 2, 3 
push: $a2->@, $a2

is_deeply: $a1, $a2
ok:  (eq_array: $a1, $a2) 

my $h1 = \%:  1=>1, 2=>2, 3=>3 
$h1->{+4} = $h1
my $h2 = \%:  1=>1, 2=>2, 3=>3 
$h2->{+4} = $h2

is_deeply: $h1, $h2
ok:  (eq_hash: $h1, $h2) 

my ($r, $s)

$r = \$r
$s = \$s

ok:  (eq_array: \(@: $s), \(@: $r)) 


do
    # Classic set of circular scalar refs.
    my($a,$b,$c)
    $a = \$b
    $b = \$c
    $c = \$a

    my($d,$e,$f)
    $d = \$e
    $e = \$f
    $f = \$d

    is_deeply:  $a, $a 
    is_deeply:  $a, $d 



do
    # rt.cpan.org 11623
    # Make sure the circular ref checks don't get confused by a reference
    # which is simply repeating.
    my $a = \$%
    my $b = \$%
    my $c = \$%

    is_deeply:  \(@: $a, $a), \(@: $b, $c) 
    is_deeply:  \(%:  foo => $a, bar => $a ), \(%:  foo => $b, bar => $c ) 
    is_deeply:  \(@: \$a, \$a), \(@: \$b, \$c) 

