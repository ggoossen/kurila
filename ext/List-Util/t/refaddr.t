#!./perl

use Config

use Test::More tests => 11

use Scalar::Util < qw(refaddr)
our ($t, $y, $x)
use Symbol < qw(gensym)

my $i = 1
foreach my $v (@: undef, 10, 'string')
    is: (refaddr: $v), undef, "not " . ((defined: $v) ?? "'$v'" !! "undef")


foreach my $r (@: \$%, \$t, \$@, \sub {})
    my $n = dump::view: $r
    $n =~ m/0x(\w+)/
    my $addr = do { local $^WARNING = undef; hex $1 }
    my $before = ref: $r
    is:  (refaddr: $r), $addr, $n
    is:  (ref: $r), $before, $n


package Hash3

use Scalar::Util < qw(refaddr)

sub TIEHASH
    my $pkg = shift
    return bless: \(@:  < @_ ), $pkg

sub FETCH
    my $self = shift
    my $key = shift
    my (@: $underlying) =  $self->@
    return $underlying->{?(refaddr: $key)}

sub STORE
    my $self = shift
    my $key = shift
    my $value = shift
    my (@: $underlying) =  $self->@
    return  @: $underlying->{+(refaddr: $key)} = $key

