use strict;
use warnings;

BEGIN {
    if (%ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }
}

use Test::More;
plan tests => 31;

use threads::shared;

### Start of Testing ###

# Make sure threads are really off
ok( !%INC{"threads.pm"} );

# Check each faked function.
foreach my $func (qw(share cond_wait cond_signal cond_broadcast)) {
    ok( my $func_ref = __PACKAGE__->can($func) ? 1 : 0 );

    eval qq{$func()};
    like( $@->{description}, qr/^Not enough arguments / );

    my %hash = (foo => 42, bar => 23);
    eval qq{$func(\%hash)};
    is( $@, '' );
    is( %hash{foo}, 42 );
    is( %hash{bar}, 23 );
}

# These all have no return value.
foreach my $func (qw(cond_wait cond_signal cond_broadcast)) {
    my @array = qw(1 2 3 4);
    is( eval qq{$func(\@array)}, undef );
    is( "@array", "1 2 3 4" );
}

# share() is supposed to return back it's argument as a ref.
{
    my @array = qw(1 2 3 4);
    is_deeply( share(@array), \@array );
    is( ref &share(\%()), 'HASH' );
    is( "@array", "1 2 3 4" );
}

# lock() should be a no-op.  The return value is currently undefined.
{
    my @array = qw(1 2 3 4);
    lock(@array);
    is( "@array", "1 2 3 4" );
}

# EOF
