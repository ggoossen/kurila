#!./perl

BEGIN { require './test.pl'; }

plan 11;

sub foo($x) {
    return $x;
}

is( foo(3), 3 );

sub recur($x) {
    if ($x eq 'depth2') {
        return $x;
    }
    my $v = recur('depth2');
    return @: $x, $v;
}

my @($r1, $r2) = recur('depth1');
is($r1, 'depth1');
is($r2, 'depth2');

sub emptyproto() {
    return 'foo';
}

is( emptyproto(), 'foo' );
is( emptyproto . 'bar', 'foobar' );

BEGIN {
    my $x = 11;
    *baz = sub () { $x };
}

is( baz + 1, 12 );

my $sub = sub ($x) { ++$x };
is($sub->(4), 5);

sub threeargs($x, $y, $z) {
    return 1;
}
dies_like( { threeargs(1, 2) },
           qr/Not enough arguments for main::threeargs/ );
dies_like( { threeargs(1, 2, 3, 4) },
           qr/Too many arguments for main::threeargs/ );
