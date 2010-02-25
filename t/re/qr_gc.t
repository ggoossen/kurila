#!./perl -w

BEGIN
    require './test.pl'

plan: tests => 2

our $TODO = "leaking since 32751"

my $destroyed

do
    no warnings 'redefine'
    sub Regexp::DESTROY($self)
        $destroyed++

do
    my $rx = qr//

is:  $destroyed, 1, "destroyed regexp" 

undef $destroyed

do
    my $var = bless: \$%, "Foo"
    my $rx = qr/(?{ $var })/

is:  $destroyed, 1, "destroyed regexp with closure capture" 

