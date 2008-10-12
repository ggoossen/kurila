#!perl -T

BEGIN {
    use Config;
    use Test::More;
    plan skip_all => "POSIX is unavailable" 
        if %Config{'extensions'} !~ m!\bPOSIX\b!;
}
use strict;
use POSIX;
BEGIN {
    plan skip_all => "POSIX::Termios not implemented" 
        if  !eval "POSIX::Termios->new;1"
        and $@->{description}=~m/not implemented/;
}


my @getters = qw(getcflag getiflag getispeed getlflag getoflag getospeed);

plan tests => 3 + 2 * (3 + NCCS() + nelems @getters);

my $r;

# create a new object
my $termios = try { POSIX::Termios->new };
is( $@, '', "calling POSIX::Termios->new" );
ok( defined $termios, "\tchecking if the object is defined" );
isa_ok( $termios, "POSIX::Termios", "\tchecking the type of the object" );

# testing getattr()

SKIP: do {
    -t *STDIN or skip("STDIN not a tty", 2);
    $r = try { $termios->getattr(0) };
    is( $@, '', "calling getattr(0)" );
    ok( defined $r, "\tchecking if the returned value is defined: $r" );
};

SKIP: do {
    -t *STDOUT or skip("STDOUT not a tty", 2);
    $r = try { $termios->getattr(1) };
    is( $@, '', "calling getattr(1)" );
    ok( defined $r, "\tchecking if the returned value is defined: $r" );
};

SKIP: do {
    -t *STDERR or skip("STDERR not a tty", 2);
    $r = try { $termios->getattr(2) };
    is( $@, '', "calling getattr(2)" );
    ok( defined $r, "\tchecking if the returned value is defined: $r" );
};

# testing getcc()
for my $i (0..NCCS()-1) {
    $r = try { $termios->getcc($i) };
    is( $@, '', "calling getcc($i)" );
    ok( defined $r, "\tchecking if the returned value is defined: $r" );
}

# testing getcflag()
for my $method ( @getters) {
    $r = try { $termios->?$method() };
    is( $@, '', "calling $method()" );
    ok( defined $r, "\tchecking if the returned value is defined: $r" );
}

