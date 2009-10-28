#!perl
#
# regression tests for old bugs that don't fit other categories


use Test::More tests => 2
use Data::Dumper

do
    sub iterate_hash($h)
        my $count = 0
        $count++ while each $h->%
        return $count
    


# [perl #38612] Data::Dumper core dump in 5.8.6, fixed by 5.8.7
sub foo
    my $s = shift
    local $Data::Dumper::Terse = 1
    my $c = eval Dumper: $s
    sub bar::quote { }
    bless: $c, 'bar'
    my $d = Data::Dumper->new: \(@: $c)
    $d->Freezer: 'quote'
    return $d->Dump: 

foo: \$%
ok: 1, "[perl #38612]" # Still no core dump? We are fine.

do
    my %h = %: 1,2,3,4
    each %h

    my $d = Data::Dumper->new: \(@: \%h)
    $d->Useqq: 1
    my $txt = $d->Dump: 
    my $VAR1
    eval $txt
    is_deeply: $VAR1, \%h, '[perl #40668] Reset hash iterator'

