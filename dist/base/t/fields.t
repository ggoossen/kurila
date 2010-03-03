#!/usr/bin/perl -w

use Test::More tests => 15

BEGIN { (use_ok: 'fields'); }


package Foo

use fields < qw(_no Pants who _up_yours)
use fields < qw(what)

sub new { (fields::new: shift) }
sub magic_new { (bless: \$@) }  # Doesn't 100% work, perl's problem.

package main

is_deeply:  \((sort: keys %Foo::FIELDS))
            \sort: qw(_no Pants who _up_yours what)
           

sub show_fields
    my(@: $base, $mask) =  @_
    my $fields = \(Symbol::fetch_glob: $base.'::FIELDS')->*->%
    return grep: { (%fields::attr{$base}->[$fields->{?$_}] ^&^ $mask) == $mask},
                     keys $fields->%


is_deeply:  \(sort: (show_fields: 'Foo', (fields::PUBLIC: )))
            \sort: qw(Pants who what)
is_deeply:  \(sort: (show_fields: 'Foo', (fields::PRIVATE: )))
            \sort: qw(_no _up_yours)

foreach ((@: (Foo->new: )))
    my $obj = $_
    my %test = %:  Pants => 'Whatever', _no => 'Yeah'
                   what  => 'Ahh',      who => 'Moo'
                   _up_yours => 'Yip' 

    $obj->{+Pants} = 'Whatever'
    $obj->{+_no}   = 'Yeah'
    $obj->{[qw(what who _up_yours)]} = @: 'Ahh', 'Moo', 'Yip'

    while(my(@: ?$k,?$v) =(@:  each %test))
        is: $obj->{?$k}, $v
    


do
    local $^WARN_HOOK = sub (@< @_)
        return if @_[0] =~ m/^Pseudo-hashes are deprecated/
    
    my $phash
    try { $phash = (fields::phash: name => "Joe", rank => "Captain") }
    like: $^EVAL_ERROR->{?description}, qr/^Pseudo-hashes have been removed from Perl/



# check if fields autovivify
do
    package Foo::Autoviv
    use fields < qw(foo bar)
    sub new { (fields::new: @_[0]) }

    package main
    my $a = Foo::Autoviv->new
    $a->{+foo} = \@: 'a', 'ok', 'c'
    $a->{+bar} = \%:  A => 'ok' 
    is:  $a->{foo}->[1],    'ok' 
    is:  $a->{bar}->{?A},, 'ok' 


package Test::FooBar

use fields < qw(a b c)

sub new
    my $self = fields::new: shift
    my (@: %<%h) =  @_ if (nelems @_)
    for (keys %h)
        $self->{+$_} = %h{$_}
    $self


package main

do
    my $x = Test::FooBar->new:  a => 1, b => 2

    is: ref $x, 'Test::FooBar', 'x is a Test::FooBar'
    ok: exists $x->{a}, 'x has a'
    ok: exists $x->{b}, 'x has b'

